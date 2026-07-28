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
//   FCM_SERVER_KEY   — optional. If unset, push multicast is silently skipped.

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
        return await handleForceRefresh(ctx, env);
      }
      if (url.pathname === '/subscribe' && request.method === 'POST') {
        return await handleSubscribe(request, env);
      }
      if (url.pathname === '/subscribe' && request.method === 'DELETE') {
        return await handleUnsubscribe(request, env);
      }
      return json({ error: 'not_found' }, 404);
    } catch (e) {
      console.error('worker_error', { path: url.pathname, error: String(e) });
      return json({ error: 'internal', message: String(e) }, 500);
    }
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(refreshArticlesAndMaybeNotify(env));
  },
};

// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------

async function handleArticles(url, env) {
  const page = Math.max(1, parseInt(url.searchParams.get('page') || '1', 10));
  const pageSize = Math.min(100, Math.max(1, parseInt(url.searchParams.get('pageSize') || '50', 10)));

  const articles = await loadArticles(env);
  const total = articles.length;
  const start = (page - 1) * pageSize;
  const items = articles.slice(start, start + pageSize);
  const hasMore = start + pageSize < total;
  return json({ items, total, hasMore });
}

async function handleForceRefresh(ctx, env) {
  const articles = await refreshArticlesAndMaybeNotify(env);
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

  // Store the subscription.
  await env.ARTICLES_KV.put(`sub:${token}`, JSON.stringify({
    token,
    topic: body.topic || 'new-articles',
    preferences: prefs,
    createdAt: Date.now(),
  }));

  // Subscribe the token to the FCM topic. Best-effort: if FCM_SERVER_KEY
  // isn't configured we keep the record but skip the actual subscription.
  if (env.FCM_SERVER_KEY) {
    const resp = await fetch('https://iid.googleapis.com/iid/v1:batchAdd', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${env.FCM_SERVER_KEY}`,
      },
      body: JSON.stringify({
        to: '/topics/new-articles',
        registration_tokens: [token],
      }),
    });
    if (resp.status !== 200) {
      console.error('fcm_subscribe_failed', { status: resp.status });
    }
  }

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
  await env.ARTICLES_KV.delete(`sub:${token}`);

  if (env.FCM_SERVER_KEY) {
    await fetch('https://iid.googleapis.com/iid/v1:batchRemove', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${env.FCM_SERVER_KEY}`,
      },
      body: JSON.stringify({
        to: '/topics/new-articles',
        registration_tokens: [token],
      }),
    });
  }

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
  const articles = await fetchAllSources();
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

  if (newIds.length > 0 && env.FCM_SERVER_KEY) {
    await announceNewArticles(articles.slice(0, 3), env.FCM_SERVER_KEY);
  }
  return articles;
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
    const xml = await response.text();
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
  const pubDate = parseDate(pubDateRaw);
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
// FCM topic multicast — only fires with FCM_SERVER_KEY.
// ---------------------------------------------------------------------------

async function announceNewArticles(articles, serverKey) {
  if (articles.length === 0) return;
  try {
    await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${serverKey}`,
      },
      body: JSON.stringify({
        to: '/topics/new-articles',
        notification: {
          title: 'New articles just dropped',
          body: articles[0]?.title || 'Fresh feed is ready',
        },
        data: {
          type: 'new_articles',
          count: String(articles.length),
        },
      }),
    });
  } catch (e) {
    console.error('fcm_send_failed', { error: String(e) });
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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
  if (!s) return Date.now();
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
  return Number.isNaN(t) ? Date.now() : t;
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
  const r = new Response(response.body, response);
  r.headers.set('Access-Control-Allow-Origin', '*');
  r.headers.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  r.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  return r;
}
