// Cloudflare Worker for Curated Feeds.
//
// Endpoints:
//   GET    /articles?page=N&pageSize=M   → paginated merged feed
//   GET    /articles/refresh             → bypass cache
//   POST   /subscribe                    → register FCM token for new-articles
//   DELETE /subscribe                    → remove FCM token
//   GET    /health                       → liveness
//
// Architecture: KV-backed article cache (5-min TTL via `expirationTtl` on
// put), refreshed on demand when expired, plus a 5-min cron that pre-warms.
// No module-scope mutable state: cache + seen-id set both live in KV.
//
// Secrets (configure via `wrangler secret put NAME`):
//   FCM_SERVICE_ACCOUNT  — JSON.stringify of the service account private key
//                          from Firebase console. Without it, push multicast
//                          is silently skipped.
//   FCM_PROJECT_ID       — Firebase project id ("curatedfeeds").

// ---------------------------------------------------------------------------
// Canonical source list — must stay in sync with
// lib/services/rss_feed_service.dart
// ---------------------------------------------------------------------------

const SOURCES = [
  { id: 'verge',        name: 'The Verge',     url: 'https://www.theverge.com/rss/index.xml',        category: 'Tech',          color: '#60A5FA', icon: 'devices' },
  { id: 'wired',        name: 'Wired',         url: 'https://www.wired.com/feed/rss',                category: 'Tech',          color: '#60A5FA', icon: 'memory' },
  { id: 'bbc',          name: 'BBC World',     url: 'https://feeds.bbci.co.uk/news/rss.xml',          category: 'News',          color: '#DC2626', icon: 'public' },
  { id: 'newscientist', name: 'New Scientist', url: 'https://www.newscientist.com/feed/home/',        category: 'Science',       color: '#22D3EE', icon: 'biotech' },
  { id: 'skysports',    name: 'Sky Sports',    url: 'https://www.skysports.com/rss/12040',            category: 'Sports',        color: '#34D399', icon: 'sports_soccer' },
  { id: 'variety',      name: 'Variety',       url: 'https://variety.com/feed/',                      category: 'Entertainment', color: '#7C3AED', icon: 'theaters' },
  { id: 'arstechnica',  name: 'Ars Technica',  url: 'https://feeds.arstechnica.com/arstechnica/index', category: 'Tech',          color: '#60A5FA', icon: 'computer' },
  { id: 'techcrunch',   name: 'TechCrunch',    url: 'https://techcrunch.com/feed/',                   category: 'Tech',          color: '#60A5FA', icon: 'rocket_launch' },
  { id: 'engadget',     name: 'Engadget',      url: 'https://www.engadget.com/rss.xml',                category: 'Tech',          color: '#60A5FA', icon: 'devices_other' },
  { id: 'guardian',     name: 'The Guardian',  url: 'https://www.theguardian.com/world/rss',          category: 'News',          color: '#DC2626', icon: 'newspaper' },
  { id: 'ign',          name: 'IGN',           url: 'https://feeds.ign.com/ign/games-all',            category: 'Gaming',        color: '#A78BFA', icon: 'sports_esports' },
  { id: 'nasa',         name: 'NASA',          url: 'https://www.nasa.gov/rss/dyn/breaking_news.rss', category: 'Science',       color: '#22D3EE', icon: 'rocket' },
];

const ARTICLES_CACHE_KEY = 'articles:v1';
const SEEN_IDS_KEY = 'seen-ids:v1';
const ARTICLES_TTL_SECONDS = 5 * 60;
const REFRESH_LOCK_KEY = 'refresh:lock';
const MAX_XML_BYTES = 5 * 1024 * 1024;
const CORS_ALLOWED_ORIGIN = 'https://curated-feeds-worker.raj15400881.workers.dev';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return cors(new Response(null, { status: 204 }));
    }

    try {
      if (url.pathname === '/health') {
        return json({ ok: true, ts: Date.now() });
      }
      if (url.pathname === '/articles' && request.method === 'GET') {
        return await handleArticles(url, env);
      }
      if (url.pathname === '/articles/refresh' && request.method === 'GET') {
        if (!isAuthorized(request, env)) return json({ error: 'unauthorized' }, 401);
        const refreshIp = request.headers.get('CF-Connecting-IP') ?? 'local';
        if (!(await consumeRate(env, 'refresh:' + refreshIp, 5, 60))) {
          return json({ error: 'rate_limited' }, 429);
        }
        return await handleForceRefresh(ctx, env);
      }
      if (url.pathname === '/subscribe' && request.method === 'POST') {
        if (!isAuthorized(request, env)) return json({ error: 'unauthorized' }, 401);
        return await handleSubscribe(request, env);
      }
      if (url.pathname === '/subscribe' && request.method === 'DELETE') {
        if (!isAuthorized(request, env)) return json({ error: 'unauthorized' }, 401);
        return await handleUnsubscribe(request, env);
      }
      return json({ error: 'not_found' }, 404);
    } catch (e) {
      console.error('worker_error', { path: url.pathname, error: String(e) });
      return json({ error: 'internal', message: String(e) }, 500);
    }
  },

  async scheduled(_event, env, ctx) {
    // waitUntil returns immediately, so an async rejection can't surface in
    // the try/catch — attach the handler to the returned promise instead.
    ctx.waitUntil(
      refreshArticlesAndMaybeNotify(env).catch((e) => {
        console.error('scheduled_refresh_failed', { error: String(e) });
      }),
    );
  },
};

// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------

function isAuthorized(request, env) {
  if (!env.API_SECRET) {
    // Not configured yet → open for back-compat. Loud so a live deployment
    // can't silently run without the gate.
    console.warn('api_secret_not_configured');
    return true;
  }
  return request.headers.get('x-api-secret') === env.API_SECRET;
}

async function consumeRate(env, key, limit, windowSec) {
  const win = Math.floor(Date.now() / (windowSec * 1000));
  const k = `rl:${key}:${win}`;
  const cur = await env.ARTICLES_KV.get(k, 'json');
  if (cur && cur.n >= limit) return false;
  await env.ARTICLES_KV.put(k, JSON.stringify({ n: (cur?.n ?? 0) + 1 }), { expirationTtl: windowSec * 2 });
  return true;
}

async function handleArticles(url, env) {
  const pageRaw = parseInt(url.searchParams.get('page') || '1', 10);
  const page = Number.isFinite(pageRaw) ? Math.max(1, pageRaw) : 1;
  const sizeRaw = parseInt(url.searchParams.get('pageSize') || '50', 10);
  const pageSize = Number.isFinite(sizeRaw) ? Math.min(100, Math.max(1, sizeRaw)) : 50;

  const articles = await loadArticles(env);
  if (articles === null) {
    return json({ error: 'busy', message: 'Feed is refreshing' }, 503);
  }
  const total = articles.length;
  const start = (page - 1) * pageSize;
  const items = articles.slice(start, start + pageSize);
  const hasMore = start + pageSize < total;
  return json({ items, total, hasMore });
}

async function handleForceRefresh(ctx, env) {
  const articles = await refreshArticlesAndMaybeNotify(env);
  if (articles === null) {
    return json({ error: 'busy', message: 'Feed is refreshing' }, 503);
  }
  return json({ items: articles.slice(0, 50), total: articles.length, refreshed: true });
}

async function handleSubscribe(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }
  const token = body?.token;
  if (typeof token !== 'string' || token.length < 10) {
    return json({ error: 'missing_token' }, 400);
  }
  const prefs = body?.preferences && typeof body.preferences === 'object' ? body.preferences : {};

  const subIp = request.headers.get('CF-Connecting-IP') ?? 'local';
  if (!(await consumeRate(env, 'sub:' + token + subIp, 10, 60))) {
    return json({ error: 'rate_limited' }, 429);
  }

  // Store the subscription. 90-day rolling TTL; refreshed on each app launch.
  await env.ARTICLES_KV.put(`sub:${token}`, JSON.stringify({
    token,
    topic: body.topic || 'new-articles',
    preferences: prefs,
    createdAt: Date.now(),
  }), { expirationTtl: 90 * 24 * 3600 });

  // Push delivery is per-token (announceNewArticles reads the sub:* rows), so
  // no topic registration is needed — the stored row is enough.
  return json({ ok: true });
}

async function handleUnsubscribe(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'invalid_json' }, 400);
  }
  const token = body?.token;
  if (typeof token !== 'string' || token.length < 10) {
    return json({ error: 'missing_token' }, 400);
  }

  const unsubIp = request.headers.get('CF-Connecting-IP') ?? 'local';
  if (!(await consumeRate(env, 'unsub:' + token + unsubIp, 10, 60))) {
    return json({ error: 'rate_limited' }, 429);
  }

  await env.ARTICLES_KV.delete(`sub:${token}`);

  // No IID topic cleanup needed — delivery is per-token via the sub:* rows,
  // and deleting the row is what stops future announces reaching the token.
  return json({ ok: true });
}

// ---------------------------------------------------------------------------
// Article cache (KV) — load with refresh-on-miss / refresh-on-stale
// ---------------------------------------------------------------------------

async function loadArticles(env) {
  const cached = await env.ARTICLES_KV.get(ARTICLES_CACHE_KEY, 'json');
  if (cached && Array.isArray(cached)) {
    return cached;
  }
  return refreshArticlesAndMaybeNotify(env);
}

async function refreshArticlesAndMaybeNotify(env) {
  const lock = await env.ARTICLES_KV.get(REFRESH_LOCK_KEY);
  if (lock === '1') {
    const cached = await env.ARTICLES_KV.get(ARTICLES_CACHE_KEY, 'json');
    if (Array.isArray(cached) && cached.length) return cached;
    // A refresh is mid-flight and there's no cache to serve. Return null so
    // callers (handleArticles / handleForceRefresh) answer 503 "busy" instead
    // of a misleading empty feed.
    return null;
  }
  // KV refuses expirationTtl < 60; a 60s lock is still far shorter than the
  // 5-min cron cadence, so the thundering-herd protection is unchanged.
  await env.ARTICLES_KV.put(REFRESH_LOCK_KEY, '1', { expirationTtl: 60 });
  try {
    const articles = await fetchAllSources();
    // Every source failed this cycle — don't clobber a good cache with an
    // empty feed (the app would read "nothing new" for a full TTL window).
    if (articles.length === 0) {
      const stale = await env.ARTICLES_KV.get(ARTICLES_CACHE_KEY, 'json');
      return Array.isArray(stale) && stale.length ? stale : [];
    }
    // Read previous seen-ids before overwriting
    const seen = (await env.ARTICLES_KV.get(SEEN_IDS_KEY, 'json')) || [];
    const seenSet = new Set(seen);

    const newIds = [];
    for (const a of articles) {
      if (!seenSet.has(a.id)) {
        newIds.push(a.id);
        seenSet.add(a.id);
      }
    }

    // Persist — KV with TTL so we naturally expire to "cold" between crons.
    await env.ARTICLES_KV.put(ARTICLES_CACHE_KEY, JSON.stringify(articles), {
      expirationTtl: ARTICLES_TTL_SECONDS * 2, // keep alive through 2 cron ticks
    });
    // Seen IDs get a longer TTL — we want them to outlive article cache so the
    // next refresh still recognises genuinely-new vs "we already know about"
    // articles.
    await env.ARTICLES_KV.put(SEEN_IDS_KEY, JSON.stringify([...seenSet]), {
      expirationTtl: 24 * 60 * 60,
    });

    if (newIds.length > 0 && env.FCM_SERVICE_ACCOUNT && env.FCM_PROJECT_ID) {
      try {
        await announceNewArticles(articles.slice(0, 3), env);
      } catch (e) {
        // A push failure must never fail a refresh that already succeeded.
        console.error('announce_failed', { error: String(e) });
      }
    }
    return articles;
  } finally {
    await env.ARTICLES_KV.delete(REFRESH_LOCK_KEY);
  }
}

async function fetchAllSources() {
  const results = await Promise.allSettled(
    SOURCES.map(source => fetchSourceArticles(source)),
  );
  const fresh = [];
  for (const r of results) {
    if (r.status === 'fulfilled') {
      fresh.push(...r.value);
    }
  }
  // Dedupe
  const seen = new Set();
  const deduped = [];
  for (const a of fresh) {
    if (!seen.has(a.id)) {
      seen.add(a.id);
      deduped.push(a);
    }
  }
  deduped.sort((a, b) => b.pubDate - a.pubDate);
  return deduped;
}

async function fetchSourceArticles(source) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(source.url, {
      signal: controller.signal,
      headers: { 'User-Agent': 'Curated-Feeds-Worker/1.0 (+rss)' },
    });
    if (!response.ok) {
      console.warn('source_fetch_failed', { source: source.id, status: response.status });
      return [];
    }
    const xml = await readTextCapped(response, MAX_XML_BYTES);
    if (xml === null) {
      console.warn('source_too_large', { source: source.id });
      return [];
    }
    return parseRss(xml, source);
  } catch (e) {
    console.warn('source_fetch_error', { source: source.id, error: String(e) });
    return [];
  } finally {
    clearTimeout(timeout);
  }
}

// ---------------------------------------------------------------------------
// RSS / Atom parsing — minimal, tolerant, no external deps.
// ---------------------------------------------------------------------------

function parseRss(xml, source) {
  const isAtom = /<feed[\s>]/i.test(xml);
  return isAtom ? extractAtomEntries(xml, source) : extractRssItems(xml, source);
}

function extractRssItems(xml, source) {
  const items = [];
  const itemRe = /<item\b[^>]*>([\s\S]*?)<\/item>/gi;
  let m;
  while ((m = itemRe.exec(xml)) !== null && items.length < 50) {
    const article = buildArticle(m[1], source, {
      titleTag: 'title',
      linkTag: 'link',
      descTag: 'description',
      pubDateTag: 'pubDate',
      authorTag: 'author',
      fullContentTag: 'content:encoded',
    });
    if (article) items.push(article);
  }
  return items;
}

function extractAtomEntries(xml, source) {
  const items = [];
  const entryRe = /<entry\b[^>]*>([\s\S]*?)<\/entry>/gi;
  let m;
  while ((m = entryRe.exec(xml)) !== null && items.length < 50) {
    const body = m[1];
    const linkMatch = body.match(/<link\b[^>]*href="([^"]+)"/i);
    const link = linkMatch ? linkMatch[1] : strip(extractTag(body, 'id'));
    const article = buildArticle(body, source, {
      titleTag: 'title',
      linkTag: null,
      linkOverride: link,
      descTag: 'summary',
      pubDateTag: 'published',
      authorTag: 'name',
      fullContentTag: 'content',
    });
    if (article) items.push(article);
  }
  return items;
}

function buildArticle(body, source, opts) {
  const title = strip(extractTag(body, opts.titleTag));
  const link = opts.linkOverride ?? strip(extractTag(body, opts.linkTag));
  if (!title || !link) return null;

  const description = strip(
    extractTag(body, opts.descTag) || extractTag(body, opts.fullContentTag)
  );
  const pubDateRaw = strip(extractTag(body, opts.pubDateTag));
  const pubDate = parseDate(pubDateRaw) ?? 0;
  const author = strip(extractTag(body, opts.authorTag)) || null;

  const mediaMatch = body.match(/<media:content\b[^>]*url="([^"]+)"/i);
  const enclosureMatch = body.match(/<enclosure\b[^>]*url="([^"]+\.(?:jpg|jpeg|png|webp|gif))"/i);
  const imgMatch = body.match(/<img\b[^>]*src="([^"]+)"/i);
  const imageUrl = (mediaMatch && mediaMatch[1])
    || (enclosureMatch && enclosureMatch[1])
    || (imgMatch && imgMatch[1])
    || null;

  return {
    id: stableId(source.id, link),
    title,
    description,
    fullContent: description,
    link,
    sourceId: source.id,
    sourceName: source.name,
    pubDate,
    author,
    imageUrl,
    sourceCategory: source.category,
    sourceColor: source.color,
    sourceIcon: source.icon,
    isRead: false,
    isSaved: false,
    fetchedFullContent: null,
  };
}

// ---------------------------------------------------------------------------
// FCM HTTP v1 — OAuth2 via service account JWT → fcm.googleapis.com/v1
// Access tokens cached in KV for 55 min under key `fcm:access-token`.
// ---------------------------------------------------------------------------

async function announceNewArticles(articles, env) {
  if (articles.length === 0) return;

  // Dedupe against a refresh racing to announce the same ids: KV has no
  // compare-and-swap, so two concurrent refreshes can both reach this step.
  // Mark ids as announced (24h TTL) and only send for ones we marked first.
  const fresh = [];
  for (const a of articles) {
    const k = 'announced:' + a.id;
    if ((await env.ARTICLES_KV.get(k)) !== null) continue;
    await env.ARTICLES_KV.put(k, '1', { expirationTtl: 24 * 60 * 60 });
    fresh.push(a);
  }
  if (fresh.length === 0) return;

  const accessToken = await getFcmAccessToken(env);
  if (!accessToken) return;

  // Per-token delivery instead of a topic multicast: read every subscription
  // row and send only to tokens whose owner hasn't opted out of "new
  // articles". The app re-POSTs /subscribe with preferences.newArticles when
  // the toggle flips, so the stored row is the source of truth.
  const projectId = env.FCM_PROJECT_ID;
  const optedIn = await optedInTokens(env);
  if (optedIn.length === 0) return;

  const latestTitle = fresh[0]?.title || 'Fresh feed is ready';
  const message = {
    message: {
      // ponytail: capped at 500 tokens per multicast; chunk if the list ever
      // outgrows it.
      registration_tokens: optedIn.slice(0, 500),
      notification: {
        title: 'New articles just dropped',
        body: latestTitle,
      },
      data: {
        type: 'new_articles',
        count: String(fresh.length),
      },
      android: {
        priority: 'HIGH',
      },
    },
  };

  try {
    const resp = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify(message),
      },
    );
    if (resp.status !== 200) {
      console.error('fcm_send_bad_status', { status: resp.status, body: await resp.text() });
    }
  } catch (e) {
    console.error('fcm_send_failed', { error: String(e) });
  }
}

// All opted-in subscription tokens. Reads every `sub:*` KV row, skipping
// rows where the owner disabled "new articles".
async function optedInTokens(env) {
  const tokens = [];
  let cursor;
  do {
    const page = await env.ARTICLES_KV.list({ prefix: 'sub:', cursor });
    for (const { name } of page.keys) {
      const row = await env.ARTICLES_KV.get(name, 'json');
      if (!row || typeof row.token !== 'string') continue;
      if (row.preferences && row.preferences.newArticles === false) continue;
      tokens.push(row.token);
    }
    cursor = page.cursor;
  } while (cursor);
  return tokens;
}

const FCM_TOKEN_CACHE_KEY = 'fcm:access-token';
const FCM_TOKEN_TTL_SECONDS = 55 * 60; // refresh 5 min before expiry

async function getFcmAccessToken(env) {
  const cached = await env.ARTICLES_KV.get(FCM_TOKEN_CACHE_KEY, 'json');
  if (cached?.accessToken && cached?.expiresAt > Date.now() + 60_000) {
    return cached.accessToken;
  }

  let sa;
  try {
    sa = JSON.parse(env.FCM_SERVICE_ACCOUNT);
  } catch {
    console.error('fcm_sa_invalid_json');
    return null;
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = base64UrlEncode(JSON.stringify({
    iss: sa.client_email,
    sub: sa.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  }));

  let signature;
  try {
    signature = await signRs256(`${header}.${payload}`, sa.private_key);
  } catch (e) {
    // Malformed service-account key — degrade to "no push" rather than
    // letting a hard throw break a refresh that already succeeded.
    console.error('fcm_sa_key_invalid', { error: String(e) });
    return null;
  }
  const jwt = `${header}.${payload}.${signature}`;

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  if (resp.status !== 200) {
    console.error('fcm_token_exchange_failed', { status: resp.status, body: await resp.text() });
    return null;
  }
  const data = await resp.json();
  const expiresAt = Date.now() + (data.expires_in ?? 3600) * 1000;

  await env.ARTICLES_KV.put(FCM_TOKEN_CACHE_KEY, JSON.stringify({
    accessToken: data.access_token,
    expiresAt,
  }), { expirationTtl: FCM_TOKEN_TTL_SECONDS });

  return data.access_token;
}

// RS256 sign via WebCrypto. Service account `private_key` is a PKCS#8 PEM.
async function signRs256(input, pemText) {
  const pem = pemText
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s+/g, '');
  const binaryDer = Uint8Array.from(atob(pem), c => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(input),
  );
  return base64UrlEncodeBytes(new Uint8Array(sig));
}

function base64UrlEncode(text) {
  return base64UrlEncodeBytes(new TextEncoder().encode(text));
}

function base64UrlEncodeBytes(bytes) {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

async function readTextCapped(response, maxBytes) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let text = '', total = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) { await reader.cancel(); return null; }
    text += decoder.decode(value, { stream: true });
  }
  return text + decoder.decode();
}

function extractTag(body, tag) {
  if (!tag) return null;
  const re = new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)<\\/${tag}>`, 'i');
  const m = body.match(re);
  return m ? m[1] : null;
}

function strip(s) {
  if (!s) return '';
  return s
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;|&apos;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

function parseDate(s) {
  if (!s) return null;
  // Sky Sports publishes dates like "Tue, 28 Jul 2026 18:11:00 BST" —
  // JS Date.parse rejects the BST suffix. Normalise non-RFC-2822 timezones.
  const normalized = s
    .replace(/\bBST\b/gi, '+0100')
    .replace(/\bIST\b/gi, '+0530')
    .replace(/\bEST\b/gi, '-0500')
    .replace(/\bEDT\b/gi, '-0400')
    .replace(/\bPST\b/gi, '-0800')
    .replace(/\bPDT\b/gi, '-0700');
  const t = Date.parse(normalized);
  return Number.isNaN(t) ? null : t;
}

function stableId(sourceId, link) {
  let h = 0;
  const s = sourceId + '|' + link;
  for (let i = 0; i < s.length; i++) {
    h = ((h << 5) - h + s.charCodeAt(i)) | 0;
  }
  return `${sourceId}-${(h >>> 0).toString(36)}`;
}

function json(body, status = 200) {
  return cors(new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  }));
}

function cors(response) {
  // ponytail: single-origin; read env.CORS_ORIGINS (comma-separated) + echo matching origins if browser tooling from other origins is ever needed
  const r = new Response(response.body, response);
  r.headers.set('Access-Control-Allow-Origin', CORS_ALLOWED_ORIGIN);
  r.headers.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  r.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-api-secret');
  return r;
}

export { SOURCES, parseRss, extractRssItems, extractAtomEntries, buildArticle, stableId, parseDate, extractTag, strip, signRs256, base64UrlEncode, ARTICLES_CACHE_KEY };
