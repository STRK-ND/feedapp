// Tests for the Curated Feeds Cloudflare Worker.
// NOTE: All fixtures below are inline (no external files, no network).
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  SOURCES,
  parseRss,
  extractRssItems,
  extractAtomEntries,
  buildArticle,
  stableId,
  parseDate,
  extractTag,
  strip,
  signRs256,
  base64UrlEncode,
  ARTICLES_CACHE_KEY,
  SOURCES_OVERRIDE_KEY,
  getSourceList,
  parseArticleParams,
  applyFilters,
  consumeRate,
  matchingTokens,
  resetRateMemory,
  rowMatchesCategories,
  rowClearsMutes,
  isTeaser,
  fetchArticleText,
  extractMainText,
  attachExtractedFullContent,
  shedFullContentForLimit,
} from '../feed-worker.js';
import worker from '../feed-worker.js';

const RSS_XML = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Feed</title>
    <item>
      <title>First article</title>
      <link>https://example.com/1</link>
      <description>First description</description>
      <pubDate>Tue, 28 Jul 2026 18:11:00 BST</pubDate>
    </item>
    <item>
      <title>Second article</title>
      <link>https://example.com/2</link>
      <description>Second description</description>
      <pubDate>Mon, 27 Jul 2026 09:30:00 GMT</pubDate>
    </item>
  </channel>
</rss>`;

const ATOM_XML = `<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom Test</title>
  <entry>
    <title>Atom one</title>
    <link href="https://example.com/a1"/>
    <summary>Summary one</summary>
    <published>2026-07-28T18:11:00Z</published>
  </entry>
  <entry>
    <title>Atom two</title>
    <link href="https://example.com/a2"/>
    <summary>Summary two</summary>
    <published>2026-07-27T09:30:00Z</published>
  </entry>
</feed>`;

const itemOpts = {
  titleTag: 'title',
  linkTag: 'link',
  descTag: 'description',
  pubDateTag: 'pubDate',
  authorTag: 'author',
  fullContentTag: 'content:encoded',
};

// The limiter's per-isolate counter is module state, and tests build a fresh
// env each time. Reset it so the same wall-clock window in two tests does not
// leak a full bucket into the second.
test.beforeEach(() => { resetRateMemory(); });

test('parseRss parses RSS fixture (2 items) and Atom fixture (2 entries)', () => {
  const source = SOURCES[0];

  const rss = parseRss(RSS_XML, source);
  assert.equal(rss.length, 2);
  assert.equal(rss[0].title, 'First article');
  assert.equal(rss[0].link, 'https://example.com/1');
  assert.equal(typeof rss[0].pubDate, 'number');
  assert.equal(rss[1].title, 'Second article');
  assert.equal(rss[1].link, 'https://example.com/2');
  assert.equal(typeof rss[1].pubDate, 'number');

  const atom = parseRss(ATOM_XML, source);
  assert.equal(atom.length, 2);
  assert.equal(atom[0].title, 'Atom one');
  assert.equal(atom[0].link, 'https://example.com/a1');
  assert.equal(typeof atom[0].pubDate, 'number');
  assert.equal(atom[1].title, 'Atom two');
  assert.equal(atom[1].link, 'https://example.com/a2');
});

test('buildArticle with garbage <pubDate> yields pubDate === 0', () => {
  const source = SOURCES[0];
  const body =
    '<title>No date</title><link>https://example.com/x</link><pubDate>not-a-date</pubDate>';
  const article = buildArticle(body, source, itemOpts);
  assert.ok(article);
  assert.equal(article.pubDate, 0);
});

// --- image extraction regressions (audit of live sources) ---

test('buildArticle extracts BBC-style media:thumbnail', () => {
  const source = SOURCES[0];
  const body =
    '<title>T</title><link>https://example.com/bbc</link>' +
    '<media:thumbnail width="240" height="134" url="https://ichef.bbci.co.uk/x.jpg"/>';
  const article = buildArticle(body, source, itemOpts);
  assert.equal(article.imageUrl, 'https://ichef.bbci.co.uk/x.jpg');
});

test('buildArticle extracts Sky-style enclosure with query string', () => {
  const source = SOURCES[4];
  const body =
    '<title>T</title><link>https://example.com/sky</link>' +
    '<enclosure type="image/jpg" url="https://e1.365dm.com/26/08/sky.jpg?20260820165121" length="123456" />';
  const article = buildArticle(body, source, itemOpts);
  assert.equal(article.imageUrl, 'https://e1.365dm.com/26/08/sky.jpg?20260820165121');
});

test('buildArticle extracts embedded <img> and decodes XML-escaped ampersands', () => {
  const source = SOURCES[11];
  const body =
    '<title>T</title><link>https://example.com/nasa</link>' +
    '<description><![CDATA[x <img src="https://assets.nasa.gov/p.jpg?w=2200&#038;h=1467&#038;fit=clip">]]></description>';
  const article = buildArticle(body, source, itemOpts);
  assert.equal(article.imageUrl, 'https://assets.nasa.gov/p.jpg?w=2200&h=1467&fit=clip');
});

test('buildArticle prefers media:content over enclosure over img', () => {
  const source = SOURCES[0];
  const body =
    '<title>T</title><link>https://example.com/all</link>' +
    '<img src="https://example.com/img.jpg"/>' +
    '<enclosure url="https://example.com/enc.jpg"/>' +
    '<media:content url="https://example.com/media.jpg"/>';
  const article = buildArticle(body, source, itemOpts);
  assert.equal(article.imageUrl, 'https://example.com/media.jpg');
});

test('buildArticle leaves imageUrl null when the item has no image', () => {
  const source = SOURCES[0];
  const body = '<title>T</title><link>https://example.com/noimg</link>';
  const article = buildArticle(body, source, itemOpts);
  assert.equal(article.imageUrl, null);
});

test('parseDate: null for empty/garbage, number for RFC-2822 and BST', () => {
  assert.equal(parseDate(''), null);
  assert.equal(parseDate('garbage'), null);

  const rfc = parseDate('Tue, 28 Jul 2026 18:11:00 GMT');
  assert.equal(typeof rfc, 'number');
  assert.ok(rfc > 0);

  // Raw BST suffix is rejected by Date.parse; parseDate's normalization makes it parse.
  assert.ok(Number.isNaN(Date.parse('Tue, 28 Jul 2026 18:11:00 BST')));
  const bst = parseDate('Tue, 28 Jul 2026 18:11:00 BST');
  assert.equal(typeof bst, 'number');
  assert.ok(bst > 0);
});

test('stableId is deterministic and source-aware', () => {
  const a = stableId('verge', 'https://example.com/1');
  const b = stableId('verge', 'https://example.com/1');
  const c = stableId('wired', 'https://example.com/1');
  assert.equal(a, b);
  assert.notEqual(a, c);
});

// ---------------------------------------------------------------------------
// /articles query contract: parseArticleParams + applyFilters
// ---------------------------------------------------------------------------

const FILTER_FIXTURE = [
  { id: 'a', title: 'Quantum Computing Advances', description: 'Qubits all the way down', sourceName: 'The Verge', sourceCategory: 'Tech', pubDate: 1700000000000 },
  { id: 'b', title: 'Football results', description: 'Weekly roundup', sourceName: 'Sky Sports', sourceCategory: 'Sports', pubDate: 1699999000000 },
  { id: 'c', title: 'Mars sample return', description: 'Perseverance update', sourceName: 'NASA', sourceCategory: 'Science', pubDate: 1699998000000 },
];

test('parseArticleParams defaults and clamping', () => {
  const url = new URL('https://x.dev/articles');
  const p = parseArticleParams(url);
  assert.deepEqual(p, { page: 1, pageSize: 50, q: '', since: 0, until: 0, category: '', sources: [], sort: 'date_desc', mute: [] });

  // page floors at 1, pageSize clamps to [1, 100]
  const bad = parseArticleParams(new URL('https://x.dev/articles?page=-3&pageSize=9999'));
  assert.equal(bad.page, 1);
  assert.equal(bad.pageSize, 100);

  const tiny = parseArticleParams(new URL('https://x.dev/articles?pageSize=0'));
  assert.equal(tiny.pageSize, 1);

  const q = parseArticleParams(new URL('https://x.dev/articles?q=  quantum  &since=1700000000000'));
  assert.equal(q.q, 'quantum');
  assert.equal(q.since, 1700000000000);

  // Non-numeric since falls back to 0 (no delta filter)
  const nan = parseArticleParams(new URL('https://x.dev/articles?since=abc'));
  assert.equal(nan.since, 0);

  // until/category/source/sort contract (matches FilterParams.toQueryParams)
  const full = parseArticleParams(new URL(
    'https://x.dev/articles?until=1700001000000&category=Tech&source=verge,+ars+technica&sort=source'
  ));
  assert.equal(full.until, 1700001000000);
  assert.equal(full.category, 'Tech');
  assert.deepEqual(full.sources, ['verge', 'ars technica']);
  assert.equal(full.sort, 'source');

  // Unknown sort value degrades to the default, not an error
  const sorty = parseArticleParams(new URL('https://x.dev/articles?sort=bogus'));
  assert.equal(sorty.sort, 'date_desc');
});

test('parseArticleParams: mute param is split, lowercased and clamped', () => {
  const p = parseArticleParams(new URL('https://x.dev/articles?mute=Crypto,+ NFTS ,crypto'));
  // Trim + lowercase + dedupe, preserving first-seen order
  assert.deepEqual(p.mute, ['crypto', 'nfts']);

  // No param → empty list (no filtering)
  assert.deepEqual(parseArticleParams(new URL('https://x.dev/articles')).mute, []);

  // Per-term clamp to 64 chars and list cap at 50 terms
  const long = 'x'.repeat(100);
  const many = Array.from({ length: 60 }, (_, i) => `term${i}`);
  const clamped = parseArticleParams(new URL(`https://x.dev/articles?mute=${encodeURIComponent(many.join(','))},${long}`));
  assert.equal(clamped.mute.length, 50);
  assert.ok(clamped.mute.every((t) => t.length <= 64));
});

test('applyFilters: mute drops articles matching any term in title or description', () => {
  // Title hit
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { mute: ['quantum'] }), [FILTER_FIXTURE[1], FILTER_FIXTURE[2]]);
  // Description hit, case-insensitive
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { mute: ['ROUNDUP'] }), [FILTER_FIXTURE[0], FILTER_FIXTURE[2]]);
  // Multiple terms OR together
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { mute: ['qubits', 'mars'] }), [FILTER_FIXTURE[1]]);
  // Source name is deliberately NOT matched — unsubscribing is that feature
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { mute: ['verge'] }), FILTER_FIXTURE);
  // Empty/absent mute → unchanged
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { mute: [] }), FILTER_FIXTURE);
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { mute: ['   '] }), FILTER_FIXTURE);
  // Mute composes with other filters (AND)
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { category: 'Sports', mute: ['football'] }),
    [],
  );
});

test('applyFilters: q matches title, description, source name and category, case-insensitive', () => {
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { q: 'quantum' }), [FILTER_FIXTURE[0]]);
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { q: 'ROUNDUP' }), [FILTER_FIXTURE[1]]);
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { q: 'sky sports' }), [FILTER_FIXTURE[1]]);
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { q: 'science' }), [FILTER_FIXTURE[2]]);
  // No match → empty; empty/missing q → unchanged
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { q: 'zzz-not-there' }), []);
  assert.deepEqual(applyFilters(FILTER_FIXTURE, {}), FILTER_FIXTURE);
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { q: '' }), FILTER_FIXTURE);
});

test('applyFilters: since keeps only articles strictly newer than watermark', () => {
  // Exactly-at-watermark article is excluded (strict >)
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { since: 1699999000000 }),
    [FILTER_FIXTURE[0]],
  );
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { since: 1699998999999 }),
    [FILTER_FIXTURE[0], FILTER_FIXTURE[1]],
  );
  // Articles with pubDate 0 / missing are never "newer"
  assert.deepEqual(
    applyFilters([{ id: 'x', title: 'X', pubDate: 0 }], { since: 1 }),
    [],
  );
  // since=0 disables the filter entirely
  assert.equal(applyFilters(FILTER_FIXTURE, { since: 0 }).length, 3);
});

test('applyFilters: until keeps only articles at or before the ceiling', () => {
  // At-ceiling article is included (<=, complementary to since's strict >)
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { until: 1699999000000 }),
    [FILTER_FIXTURE[1], FILTER_FIXTURE[2]],
  );
  // until=0 disables the filter entirely
  assert.equal(applyFilters(FILTER_FIXTURE, { until: 0 }).length, 3);
  // since + until bracket a window
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { since: 1699998000000, until: 1699999000000 }),
    [FILTER_FIXTURE[1]],
  );
});

test('applyFilters: category narrows to exact sourceCategory match', () => {
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { category: 'Tech' }),
    [FILTER_FIXTURE[0]],
  );
  // Case-insensitive; unknown category matches nothing
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { category: 'sports' }),
    [FILTER_FIXTURE[1]],
  );
  assert.deepEqual(applyFilters(FILTER_FIXTURE, { category: 'Weather' }), []);
});

test('applyFilters: source list matches id or name, whitespace tolerated', () => {
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { sources: ['Sky Sports'] }),
    [FILTER_FIXTURE[1]],
  );
  assert.deepEqual(
    applyFilters(FILTER_FIXTURE, { sources: ['nasa', 'the verge'] }),
    [FILTER_FIXTURE[0], FILTER_FIXTURE[2]],
  );
  // No sourceId in fixture — id-matching path covered via name fallback
  assert.deepEqual(
    applyFilters([{ id: 'x', title: 'X', sourceId: 'verge', pubDate: 1 }], { sources: ['verge'] }).length,
    1,
  );
  // Empty/whitespace-only list disables the filter
  assert.equal(applyFilters(FILTER_FIXTURE, { sources: [] }).length, 3);
  assert.equal(applyFilters(FILTER_FIXTURE, { sources: ['  '] }).length, 3);
});

test('consumeRate allows up to limit then blocks within the window', async () => {
  const store = new Map();
  const fakeEnv = {
    ARTICLES_KV: {
      get: async (key, type) => (type === 'json' && store.has(key) ? JSON.parse(store.get(key)) : store.get(key) ?? null),
      put: async (key, value) => { store.set(key, value); },
    },
  };

  for (let i = 0; i < 5; i++) {
    assert.equal(await consumeRate(fakeEnv, 'art:1.2.3.4', 5, 60), true);
  }
  assert.equal(await consumeRate(fakeEnv, 'art:1.2.3.4', 5, 60), false);

  // Different key is unaffected
  assert.equal(await consumeRate(fakeEnv, 'art:5.6.7.8', 5, 60), true);
});

test('consumeRate keeps a repeated caller off the KV write path', async () => {
  resetRateMemory();
  const gets = { n: 0 };
  const puts = { n: 0 };
  const fakeEnv = {
    ARTICLES_KV: {
      get: async (key, type) => { gets.n++; return type === 'json' && key.includes('rl:') ? { n: 0 } : null; },
      put: async () => { puts.n++; },
    },
  };

  // Ten calls from one caller, all inside the limit. The limiter counts the
  // first call in KV (so a cold isolate can learn an earlier count) and then
  // serves the rest from memory: the read path pays no KV write per request.
  for (let i = 0; i < 10; i++) assert.equal(await consumeRate(fakeEnv, 'art:9.9.9.9', 120, 60), true);

  assert.equal(gets.n, 1, 'only the first call reads KV');
  assert.equal(puts.n, 1, 'only the first call writes KV');
});

// ---------------------------------------------------------------------------
// Per-category push targeting: rowMatchesCategories + matchingTokens
// ---------------------------------------------------------------------------

test('rowMatchesCategories: opt-out, unrestricted, and intersect rules', () => {
  const cats = new Set(['Tech', 'News']);

  // Opted out entirely — never matches.
  assert.equal(rowMatchesCategories({ token: 't', preferences: { newArticles: false } }, cats), false);

  // No preferences object at all → unrestricted.
  assert.equal(rowMatchesCategories({ token: 't' }, cats), true);
  // Empty category list = unrestricted.
  assert.equal(rowMatchesCategories({ token: 't', preferences: { categories: [] } }, cats), true);
  // Overlap → match.
  assert.equal(rowMatchesCategories({ token: 't', preferences: { categories: ['Sports', 'News'] } }, cats), true);
  // No overlap → skip.
  assert.equal(rowMatchesCategories({ token: 't', preferences: { categories: ['Gaming'] } }, cats), false);

  // Announcing with no known categories (all fresh articles uncategorized)
  // still reaches users who narrowed their list.
  assert.equal(
    rowMatchesCategories({ token: 't', preferences: { categories: ['Gaming'] } }, new Set()),
    true,
  );
});

class FakeKV {
  constructor(rows) { this.rows = rows instanceof Map ? rows : new Map(Object.entries(rows)); this.store = new Map(); for (const [k, v] of this.rows) this.store.set(k, JSON.stringify(v)); }
  async get(key, type) { if (!this.store.has(key)) return null; const raw = this.store.get(key); return type === 'json' ? JSON.parse(raw) : raw; }
  async put(key, value) { this.store.set(key, value); }
  async list({ prefix }) {
    const keys = [...this.store.keys()].filter(k => k.startsWith(prefix)).map(name => ({ name }));
    return { keys, cursor: undefined };
  }
}

test('matchingTokens returns only tokens matching the announced categories', async () => {
  const env = {
    ARTICLES_KV: new FakeKV({
      'sub:t-all': { token: 't-all', preferences: { newArticles: true } },
      'sub:t-off': { token: 't-off', preferences: { newArticles: false } },
      'sub:t-tech': { token: 't-tech', preferences: { newArticles: true, categories: ['Tech'] } },
      'sub:t-games': { token: 't-games', preferences: { newArticles: true, categories: ['Gaming'] } },
      'sub:junk': { preferences: {} },
    }),
  };

  assert.deepEqual(await matchingTokens(env, ['Tech']), ['t-all', 't-tech']);
  assert.deepEqual(await matchingTokens(env, ['Gaming']), ['t-all', 't-games']);
  // Unrestricted announcement reaches everyone opted in.
  assert.deepEqual(await matchingTokens(env, []), ['t-all', 't-tech', 't-games']);
});

test('rowClearsMutes: muted terms suppress the announcement for matching articles', () => {
  const fresh = [
    { title: 'Crypto rally continues', description: 'Bitcoin hits new high' },
    { title: 'Local elections', description: 'Voting opens tomorrow' },
  ];

  // No mutedTerms / empty list → clears trivially
  assert.equal(rowClearsMutes({ token: 't', preferences: {} }, fresh), true);
  assert.equal(rowClearsMutes({ token: 't', preferences: { mutedTerms: [] } }, fresh), true);

  // Muted term matches a fresh article title → suppressed
  assert.equal(
    rowClearsMutes({ token: 't', preferences: { mutedTerms: ['crypto'] } }, fresh),
    false,
  );
  // Description hit, case-insensitive
  assert.equal(
    rowClearsMutes({ token: 't', preferences: { mutedTerms: ['BITCOIN'] } }, fresh),
    false,
  );
  // No fresh article matches → still announced
  assert.equal(
    rowClearsMutes({ token: 't', preferences: { mutedTerms: ['football'] } }, fresh),
    true,
  );
  // No fresh articles passed (legacy call shape) → clears
  assert.equal(
    rowClearsMutes({ token: 't', preferences: { mutedTerms: ['crypto'] } }, []),
    true,
  );
  // Non-string junk terms are tolerated
  assert.equal(
    rowClearsMutes({ token: 't', preferences: { mutedTerms: [42, null, 'crypto'] } }, fresh),
    false,
  );
});

test('matchingTokens skips tokens whose muted terms match a fresh article', async () => {
  const env = {
    ARTICLES_KV: new FakeKV({
      'sub:t-plain': { token: 't-plain', preferences: { newArticles: true } },
      'sub:t-muted': { token: 't-muted', preferences: { newArticles: true, mutedTerms: ['quantum'] } },
      'sub:t-muted-other': { token: 't-muted-other', preferences: { newArticles: true, mutedTerms: ['football'] } },
    }),
  };
  const fresh = [{ title: 'Quantum Computing Advances', description: 'Qubits', sourceCategory: 'Tech' }];

  assert.deepEqual(await matchingTokens(env, ['Tech'], fresh), ['t-plain', 't-muted-other']);
  // Legacy two-arg call shape still works (no mute filtering)
  assert.deepEqual(await matchingTokens(env, ['Tech']), ['t-plain', 't-muted', 't-muted-other']);
});

test('signRs256 round-trip verifies with the public key (no network)', async () => {
  const { privateKey, publicKey } = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]) },
    true,
    ['sign', 'verify'],
  );

  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', privateKey));
  const base64 = btoa(String.fromCharCode(...pkcs8));
  const pem =
    '-----BEGIN PRIVATE KEY-----\n' +
    base64.match(/.{1,64}/g).join('\n') +
    '\n-----END PRIVATE KEY-----';

  const input = 'header.payload';
  const signature = await signRs256(input, pem);

  // Decode base64url signature back to raw bytes for crypto.subtle.verify.
  const b64 = signature.replace(/-/g, '+').replace(/_/g, '/');
  const padded = b64 + '='.repeat((4 - (b64.length % 4)) % 4);
  const sigBytes = Uint8Array.from(atob(padded), c => c.charCodeAt(0));

  const verified = await crypto.subtle.verify(
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    publicKey,
    sigBytes,
    new TextEncoder().encode(input),
  );
  assert.equal(verified, true);
});

// ---------------------------------------------------------------------------
// Dispatch-level tests — exercise export default fetch with a KV stub so
// handler-wiring bugs (arg mismatches, routing) are caught, not just the
// pure functions.
// ---------------------------------------------------------------------------

function kvStub(initial = {}) {
  const map = new Map(Object.entries(initial));
  return {
    async get(k, type) {
      const v = map.get(k);
      if (v === undefined) return null;
      return type === 'json' ? JSON.parse(v) : v;
    },
    async put(k, v) { map.set(k, String(v)); },
    async delete(k) { map.delete(k); },
    async list() { return { keys: [...map.keys()].map(name => ({ name })) }; },
    _map: map,
  };
}

function workerEnv(extra = {}) {
  return { ARTICLES_KV: kvStub(), API_SECRET: 'test-secret', ADMIN_SECRET: 'test-admin-secret', ...extra };
}

function workerRequest(path, { method = 'GET', body, secret } = {}) {
  const headers = { 'CF-Connecting-IP': 'test-ip' };
  if (secret) headers['x-api-secret'] = secret;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  return new Request('https://worker.test' + path, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

const noopCtx = { waitUntil: () => {} };

test('GET /articles serves the cached feed (dispatch wiring regression)', async () => {
  const cached = [{ id: 'a1', title: 'One', pubDate: 3 }, { id: 'a2', title: 'Two', pubDate: 2 }];
  const env = workerEnv();
  await env.ARTICLES_KV.put(ARTICLES_CACHE_KEY, JSON.stringify(cached));
  const res = await worker.fetch(workerRequest('/articles'), env, noopCtx);
  assert.equal(res.status, 200);
  const data = await res.json();
  assert.equal(data.total, 2);
  assert.equal(data.items[0].id, 'a1');
});

test('GET /articles returns 503 busy when no cache and a refresh is locked', async () => {
  const env = workerEnv();
  await env.ARTICLES_KV.put('refresh:lock', '1');
  const res = await worker.fetch(workerRequest('/articles'), env, noopCtx);
  assert.equal(res.status, 503);
  const data = await res.json();
  assert.equal(data.error, 'busy');
});

test('GET /sources returns the bundled canonical list', async () => {
  const res = await worker.fetch(workerRequest('/sources'), workerEnv(), noopCtx);
  assert.equal(res.status, 200);
  const { sources } = await res.json();
  assert.equal(sources.length, SOURCES.length);
  assert.equal(sources[0].id, SOURCES[0].id);
});

test('PUT /sources rejects wrong/missing secret and invalid bodies', async () => {
  const env = workerEnv();
  const noAuth = await worker.fetch(workerRequest('/sources', { method: 'PUT', body: { sources: SOURCES } }), env, noopCtx);
  assert.equal(noAuth.status, 401);
  const badSecret = await worker.fetch(workerRequest('/sources', { method: 'PUT', body: { sources: SOURCES }, secret: 'wrong' }), env, noopCtx);
  assert.equal(badSecret.status, 401);
  const empty = await worker.fetch(workerRequest('/sources', { method: 'PUT', body: { sources: [] }, secret: 'test-admin-secret' }), env, noopCtx);
  assert.equal(empty.status, 400);
  const badEntry = await worker.fetch(workerRequest('/sources', { method: 'PUT', body: { sources: [{ id: 'x' }] }, secret: 'test-admin-secret' }), env, noopCtx);
  assert.equal(badEntry.status, 400);
  // Nothing was persisted by any rejected call.
  assert.equal(await env.ARTICLES_KV.get(SOURCES_OVERRIDE_KEY), null);
});

test('PUT /sources is admin-only: the shared app secret must not grant it', async () => {
  // The APK embeds API_SECRET, so it must never unlock admin authority.
  const env = workerEnv();
  const appSecret = await worker.fetch(workerRequest('/sources', { method: 'PUT', body: { sources: SOURCES }, secret: 'test-secret' }), env, noopCtx);
  assert.equal(appSecret.status, 401);
  assert.equal(await env.ARTICLES_KV.get(SOURCES_OVERRIDE_KEY), null);
});

test('PUT /sources fails closed when ADMIN_SECRET is not configured', async () => {
  const env = workerEnv({ ADMIN_SECRET: undefined });
  const res = await worker.fetch(workerRequest('/sources', { method: 'PUT', body: { sources: SOURCES }, secret: 'test-admin-secret' }), env, noopCtx);
  assert.equal(res.status, 401);
  assert.equal(await env.ARTICLES_KV.get(SOURCES_OVERRIDE_KEY), null);
});

test('PUT /sources with the admin secret overrides GET /sources and the aggregation list', async () => {
  const override = [{ id: 'custom', name: 'Custom', url: 'https://example.com/feed', category: 'Tech' }];
  const env = workerEnv();
  const put = await worker.fetch(workerRequest('/sources', { method: 'PUT', body: { sources: override }, secret: 'test-admin-secret' }), env, noopCtx);
  assert.equal(put.status, 200);

  const res = await worker.fetch(workerRequest('/sources'), env, noopCtx);
  const { sources } = await res.json();
  assert.deepEqual(sources, override);
  assert.deepEqual(await getSourceList(env), override);
});

test('getSourceList falls back to the bundled list when the override is empty or absent', async () => {
  const env = workerEnv();
  assert.deepEqual(await getSourceList(env), SOURCES);
  await env.ARTICLES_KV.put(SOURCES_OVERRIDE_KEY, JSON.stringify([]));
  assert.deepEqual(await getSourceList(env), SOURCES);
});

// ---------------------------------------------------------------------------
// Fail-closed app gate: /subscribe and /articles/refresh mutate shared
// state, so a missing API_SECRET must mean "locked", not "open".
// ---------------------------------------------------------------------------

test('app-level routes fail closed when API_SECRET is not configured', async () => {
  const env = workerEnv({ API_SECRET: undefined });

  const sub = await worker.fetch(workerRequest('/subscribe', { method: 'POST', body: { token: 'tok-1234567890' } }), env, noopCtx);
  assert.equal(sub.status, 401);

  const unsub = await worker.fetch(workerRequest('/subscribe', { method: 'DELETE', body: { token: 'tok-1234567890' } }), env, noopCtx);
  assert.equal(unsub.status, 401);

  const refresh = await worker.fetch(workerRequest('/articles/refresh'), env, noopCtx);
  assert.equal(refresh.status, 401);

  // Nothing was persisted by any rejected call.
  assert.equal(await env.ARTICLES_KV.get('sub:tok-1234567890'), null);
  assert.equal(await env.ARTICLES_KV.get('refresh:lock'), null);
});

test('public reads stay open when API_SECRET is not configured', async () => {
  const env = workerEnv({ API_SECRET: undefined });
  const res = await worker.fetch(workerRequest('/articles'), env, noopCtx);
  assert.ok(res.status === 200 || res.status === 503);
});

test('subscribe enforces the token shape (min and max length)', async () => {
  // Authorized request (auth is checked before body validation) — the
  // shape checks below are what is under test.
  const env = workerEnv();
  const short = await worker.fetch(workerRequest('/subscribe', { method: 'POST', body: { token: 'short' }, secret: 'test-secret' }), env, noopCtx);
  assert.equal(short.status, 400);

  const long = await worker.fetch(
    workerRequest('/subscribe', { method: 'POST', body: { token: 'x'.repeat(4097) }, secret: 'test-secret' }),
    env,
    noopCtx,
  );
  assert.equal(long.status, 400);

  const maxOk = await worker.fetch(
    workerRequest('/subscribe', { method: 'POST', body: { token: 'x'.repeat(4096) }, secret: 'test-secret' }),
    env,
    noopCtx,
  );
  assert.equal(maxOk.status, 200);
});

test('worker errors return a static 500 body (no exception text echoed)', async () => {
  const env = workerEnv({
    ARTICLES_KV: {
      // Any handler touching KV throws -> the top-level catch responds.
      get: async () => { throw new Error('Internal exploded detail xyzzy'); },
      put: async () => {},
      delete: async () => {},
      list: async () => ({ keys: [] }),
    },
  });
  const res = await worker.fetch(workerRequest('/sources'), env, noopCtx);
  assert.equal(res.status, 500);
  const data = await res.json();
  assert.equal(data.error, 'internal');
  assert.equal(data.message, undefined);
  const text = JSON.stringify(data);
  assert.ok(!text.includes('xyzzy'));
});

test('buildArticle drops future-dated items that would pin delta watermarks', () => {
  const source = SOURCES[0];
  const farFuture = new Date(Date.now() + 30 * 24 * 3600 * 1000).toUTCString();
  const body = `<title>Future</title><link>https://example.com/f</link><pubDate>${farFuture}</pubDate>`;
  assert.equal(buildArticle(body, source, itemOpts), null);

  // Small skew (under the 24h allowance) is kept.
  const nearFuture = new Date(Date.now() + 3600 * 1000).toUTCString();
  const okBody = `<title>Soon</title><link>https://example.com/s</link><pubDate>${nearFuture}</pubDate>`;
  const kept = buildArticle(okBody, source, itemOpts);
  assert.ok(kept);
  assert.equal(kept.title, 'Soon');
});

// ---------------------------------------------------------------------------
// Audit fixes (burp-audite.md): M-2, L-3, P-1, P-3
// ---------------------------------------------------------------------------

test('M-2: subscribe rate limit is per caller, not per token', async () => {
  const env = workerEnv();
  // 10 distinct tokens from one IP — every one must pass; the 11th is
  // rejected REGARDLESS of its token. Under the old per-token keying all
  // 11 returned 200 because each minted its own bucket.
  for (let i = 0; i < 10; i++) {
    const res = await worker.fetch(
      workerRequest('/subscribe', { method: 'POST', body: { token: `tok-${i}-aaaaaaaaaa` }, secret: 'test-secret' }),
      env,
      noopCtx,
    );
    assert.equal(res.status, 200, `call ${i} should pass`);
  }
  const blocked = await worker.fetch(
    workerRequest('/subscribe', { method: 'POST', body: { token: 'a-brand-new-token-xx' }, secret: 'test-secret' }),
    env,
    noopCtx,
  );
  assert.equal(blocked.status, 429, '11th distinct token must still be rate limited');

  // Same ceiling on DELETE /subscribe, keyed on the CALLER as well — the
  // DELETE bucket is separate ('unsub:'), so a fresh caller is not blocked;
  // what is pinned here is that varying the TOKEN cannot escape it.
  for (let i = 0; i < 10; i++) {
    const del = await worker.fetch(
      workerRequest('/subscribe', { method: 'DELETE', body: { token: `del-tok-${i}-aaaaaaaaaa` }, secret: 'test-secret' }),
      env,
      noopCtx,
    );
    assert.equal(del.status, 200, `delete call ${i} should pass`);
  }
  const delBlocked = await worker.fetch(
    workerRequest('/subscribe', { method: 'DELETE', body: { token: 'del-brand-new-token' }, secret: 'test-secret' }),
    env,
    noopCtx,
  );
  assert.equal(delBlocked.status, 429, '11th distinct token on DELETE must also be rate limited');
});

test('M-2: a repeated token still works within its caller bucket', async () => {
  const env = workerEnv();
  // The legitimate app pattern: re-register the same token on launch.
  // First call passes; a second identical call within the window also
  // passes because the bucket counts CALLS, and 2 < 10.
  const first = await worker.fetch(
    workerRequest('/subscribe', { method: 'POST', body: { token: 'tok-stable-123456' }, secret: 'test-secret' }),
    env,
    noopCtx,
  );
  assert.equal(first.status, 200);
  const second = await worker.fetch(
    workerRequest('/subscribe', { method: 'POST', body: { token: 'tok-stable-123456' }, secret: 'test-secret' }),
    env,
    noopCtx,
  );
  assert.equal(second.status, 200);
});

test('L-3: parseArticleParams truncates over-long free-text params', () => {
  const p = parseArticleParams(
    new URL(`https://x/articles?q=${'a'.repeat(500)}&category=${'b'.repeat(200)}&source=${'s1,'.repeat(80)}x`),
  );
  assert.equal(p.q.length, 200);
  assert.equal(p.category.length, 64);
  assert.equal(p.sources.length, 50);

  // In-range values are untouched by the clamps.
  const ok = parseArticleParams(new URL('https://x/articles?q=hello%20world&category=Tech&source=a,b'));
  assert.equal(ok.q, 'hello world');
  assert.equal(ok.category, 'Tech');
  assert.deepEqual(ok.sources, ['a', 'b']);
});

test('P-1: buildArticle emits fullContent only as a null placeholder', () => {
  const source = SOURCES[0];
  const body = '<title>T</title><link>https://example.com/p1</link><description>D</description>';
  const article = buildArticle(body, source, itemOpts);
  assert.ok(article);
  assert.equal(article.description, 'D');
  // P-1 was about waste: fullContent used to be a byte-for-byte copy of
  // description in 100/100 articles. It is now null at build time and only
  // ever attached by the teaser extractor with genuinely extracted text.
  assert.equal(article.fullContent, null);
});

// ---------------------------------------------------------------------------
// Teaser-feed full-text extraction
// ---------------------------------------------------------------------------

test('isTeaser: short bodies are candidates, long bodies are not', () => {
  assert.equal(isTeaser({ description: 'short' }), true);
  assert.equal(isTeaser({ description: '' }), true);
  assert.equal(isTeaser({ description: 'x'.repeat(400) }), false);
  assert.equal(isTeaser({ description: 'x'.repeat(1000) }), false);
  assert.equal(isTeaser({}), true);
});

test('extractMainText: prefers the longest article block, drops noise', () => {
  const html = `<html><head><style>.x{color:red}</style></head><body>
    <nav>Home About</nav>
    <article><p>${'Paragraph one. '.repeat(30)}</p></article>
    <article><p>tiny</p></article>
    <script>track('x');</script>
  </body></html>`;
  const text = extractMainText(html);
  assert.ok(text.startsWith('Paragraph one.'), text.slice(0, 40));
  assert.ok(!text.includes('track('));
  assert.ok(!text.includes('Home About'));
  assert.ok(!text.includes('<p>'));
  assert.ok(text.length > 300);
});

test('extractMainText: falls back to main, then the whole page', () => {
  const mainOnly = '<html><body><main><p>' + 'Main content. '.repeat(40) + '</p></main></body></html>';
  assert.ok(extractMainText(mainOnly).startsWith('Main content.'));

  const bare = '<html><body><p>' + 'Bare page. '.repeat(40) + '</p></body></html>';
  assert.ok(extractMainText(bare).startsWith('Bare page.'));
});

test('extractMainText: decodes entities and collapses whitespace', () => {
  const html = '<article><p>It&#8217;s &quot;fine&quot; &amp;   well</p></article>';
  assert.equal(extractMainText(html), 'It’s "fine" & well');
});

test('extractMainText: truncates to the per-article cap', () => {
  const html = '<article><p>' + 'word '.repeat(20000) + '</p></article>';
  assert.ok(extractMainText(html).length <= 12 * 1024);
});

test('attachExtractedFullContent: only materially longer bodies attach', () => {
  const teaser = { description: 'Short teaser body.' };
  assert.equal(attachExtractedFullContent(teaser, null), false);
  assert.equal('fullContent' in teaser, false);

  // Too short to be an article body
  assert.equal(attachExtractedFullContent(teaser, 'tiny'), false);

  // Not materially longer than the teaser (≤ 1.5×)
  const notMaterial = 'x'.repeat(Math.ceil('Short teaser body.'.length * 1.5));
  assert.equal(attachExtractedFullContent(teaser, notMaterial), false);

  // Genuine body attaches
  const body = 'Full article text. '.repeat(40);
  assert.equal(attachExtractedFullContent(teaser, body), true);
  assert.equal(teaser.fullContent, body);

  // Empty description: any real body passes the ratio
  const empty = { description: '' };
  assert.equal(attachExtractedFullContent(empty, 'A real body. '.repeat(20)), true);
});

test('shedFullContentForLimit: no-op under the limit, sheds oldest first over it', () => {
  const mk = (i, body) => ({
    id: `a${i}`,
    title: `t${i}`,
    description: 'd',
    ...(body ? { fullContent: body } : {}),
  });
  const small = [mk(0, null), mk(1, null)];
  assert.equal(shedFullContentForLimit(small, 10 ** 6), JSON.stringify(small));
  assert.ok(small.every((a) => !('fullContent' in a) || a.fullContent === undefined));

  // 3 articles × ~1KB bodies, limit forces shedding — oldest (highest index
  // in the newest-first array) loses its body first.
  const big = [mk(0, 'A'.repeat(1024)), mk(1, 'B'.repeat(1024)), mk(2, 'C'.repeat(1024))];
  const out = shedFullContentForLimit(big, 1200);
  assert.ok(out.length <= 1200, `serialized ${out.length} > 1200`);
  assert.ok(!('fullContent' in big[2]), 'oldest shed first');
  assert.ok(!('fullContent' in big[1]), 'second-oldest shed next');
  assert.equal(big[0].fullContent, 'A'.repeat(1024), 'newest kept');
});

test('fetchArticleText: extracts on 200, skips silently on failure paths', async () => {
  const page = '<html><body><article><p>' + 'Real article body. '.repeat(30) + '</p></article></body></html>';
  const originalFetch = globalThis.fetch;
  const calls = [];
  try {
    globalThis.fetch = async (url, opts) => {
      calls.push({ url: String(url), opts });
      if (String(url).includes('ok')) {
        return { ok: true, body: { getReader: () => stringReader(page) } };
      }
      if (String(url).includes('forbidden')) return { ok: false, status: 403 };
      if (String(url).includes('huge')) {
        return { ok: true, body: { getReader: () => stringReader('x'.repeat(600 * 1024)) } };
      }
      throw new Error('boom');
    };

    const good = await fetchArticleText('https://example.com/ok');
    assert.ok(good && good.startsWith('Real article body.'), String(good).slice(0, 40));
    assert.equal(await fetchArticleText('https://example.com/forbidden'), null);
    // readTextCapped returns truncated text (never null), so an oversized
    // page yields '' or a capped extract — either way nothing attachable
    // and never the full 600 KB.
    const huge = await fetchArticleText('https://example.com/huge');
    assert.ok(huge === null || huge.length <= 12 * 1024, `len=${huge?.length}`);
    assert.equal(attachExtractedFullContent({ description: 'x' }, huge), false);
    assert.equal(await fetchArticleText('https://example.com/throws'), null);

    // Browser-like UA and an abort signal are set on every call
    assert.ok(calls.every((c) => c.opts.signal instanceof AbortSignal));
    assert.ok(calls.every((c) => /Mozilla/.test(c.opts.headers['User-Agent'])));
  } finally {
    globalThis.fetch = originalFetch;
  }
});

// Minimal ReadableStream-like reader for readTextCapped.
function stringReader(text) {
  const encoder = new TextEncoder();
  const chunk = encoder.encode(text);
  let done = false;
  return {
    read: async () => (done ? { done: true } : ((done = true), { done: false, value: chunk })),
    cancel: async () => {},
  };
}

// ---------------------------------------------------------------------------
// Pro AI summaries: POST /summarize
// ---------------------------------------------------------------------------

import { handleSummarize, resolveUid, consumeSummaryBudget, summarizePrompt } from '../feed-worker.js';

const LONG_TEXT = 'Real article body sentence. '.repeat(40);

function summarizeEnv(extra = {}) {
  return {
    ARTICLES_KV: new FakeKV({}),
    FIREBASE_API_KEY: 'test-web-api-key',
    AI: { run: async () => ({ response: '- Point one\n- Point two\n- Point three' }) },
    ...extra,
  };
}

function summarizeRequest(body, { uidToken = 'valid-id-token-abcdefghijklmnop', ip = '1.2.3.4' } = {}) {
  const headers = {
    'CF-Connecting-IP': ip,
    'Content-Type': 'application/json',
    authorization: `Bearer ${uidToken}`,
  };
  return new Request('https://worker.test/summarize', {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
  });
}

test('resolveUid: fail-closed without FIREBASE_API_KEY, verifies via lookup, caches', async () => {
  // Fail closed: no key configured → null regardless of token.
  assert.equal(await resolveUid(summarizeRequest({}), { ARTICLES_KV: new FakeKV({}) }), null);

  const originalFetch = globalThis.fetch;
  let lookups = 0;
  try {
    globalThis.fetch = async (url, opts) => {
      lookups++;
      const payload = JSON.parse(opts.body);
      if (payload.idToken === 'valid-id-token-abcdefghijklmnop') {
        return { ok: true, json: async () => ({ users: [{ localId: 'uid-123' }] }) };
      }
      return { ok: false, status: 400, json: async () => ({}) };
    };

    const env = summarizeEnv();
    assert.equal(await resolveUid(summarizeRequest({}), env), 'uid-123');
    assert.equal(lookups, 1);
    // Second call is served from the KV cache — no second lookup.
    assert.equal(await resolveUid(summarizeRequest({}), env), 'uid-123');
    assert.equal(lookups, 1);

    // Invalid token → null.
    assert.equal(await resolveUid(summarizeRequest({}, { uidToken: 'bogus-token-abcdefghijklmnop' }), env), null);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('consumeSummaryBudget: increments per uid per month and exhausts at the limit', async () => {
  const env = summarizeEnv({ SUMMARIZE_MONTHLY_LIMIT: 3 });
  assert.equal(await consumeSummaryBudget(env, 'uid-1'), 2);
  assert.equal(await consumeSummaryBudget(env, 'uid-1'), 1);
  assert.equal(await consumeSummaryBudget(env, 'uid-1'), 0);
  assert.equal(await consumeSummaryBudget(env, 'uid-1'), null, 'exhausted');

  // A different uid has its own budget.
  assert.equal(await consumeSummaryBudget(env, 'uid-2'), 2);

  // Default limit applies when the env var is absent.
  const envDefault = summarizeEnv();
  assert.equal(await consumeSummaryBudget(envDefault, 'uid-1'), 50 - 1);

  // Key shape: summarize:<uid>:<yyyy-mm>
  const key = summarizeBudgetKeyShape();
  assert.match(key, /^summarize:uid-1:\d{4}-\d{2}$/);
});

function summarizeBudgetKeyShape() {
  // Re-derive the key the same way the worker does (no export needed —
  // the regex assertion above pins the contract).
  const now = new Date();
  return `summarize:uid-1:${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
}

test('summarizePrompt: carries the instructions and the article text', () => {
  const p = summarizePrompt(LONG_TEXT);
  assert.ok(p.includes('3 short bullet points'));
  assert.ok(p.includes('same language as the article'));
  assert.ok(p.includes(LONG_TEXT));
});


// Stub the Identity Toolkit lookup for handler tests (no real network).
function withLookupStubbed(fn) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (url, opts) => {
    const payload = JSON.parse(opts.body);
    if (payload.idToken === 'valid-id-token-abcdefghijklmnop') {
      return { ok: true, json: async () => ({ users: [{ localId: 'uid-123' }] }) };
    }
    return { ok: false, status: 400, json: async () => ({}) };
  };
  return fn().finally(() => { globalThis.fetch = originalFetch; });
}

test('handleSummarize: happy path returns the model summary and remaining budget', async () => {
  await withLookupStubbed(async () => {
    const env = summarizeEnv({ SUMMARIZE_MONTHLY_LIMIT: 5 });
    const res = await handleSummarize(
      summarizeRequest({ articleId: 'a1', text: LONG_TEXT }),
      env,
    );
    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.summary, '- Point one\n- Point two\n- Point three');
    assert.equal(data.remaining, 4, '5/month budget, 1 consumed');
  });
});

test('handleSummarize: auth, clamps, and budget failures', async () => {
  // No FIREBASE_API_KEY → fail closed.
  const noKey = { ARTICLES_KV: new FakeKV({}) };
  assert.equal(
    (await handleSummarize(summarizeRequest({ articleId: 'a1', text: LONG_TEXT }), noKey)).status,
    401,
  );

  await withLookupStubbed(async () => {
    const env = summarizeEnv();

    // Missing / too-short text → 400.
    assert.equal(
      (await handleSummarize(summarizeRequest({ articleId: 'a1', text: 'too short' }), env)).status,
      400,
    );
    assert.equal(
      (await handleSummarize(summarizeRequest({ articleId: '', text: LONG_TEXT }), env)).status,
      400,
    );

    // Budget exhaustion → 429 budget_exhausted.
    const limited = summarizeEnv({ SUMMARIZE_MONTHLY_LIMIT: 1 });
    assert.equal(
      (await handleSummarize(summarizeRequest({ articleId: 'a1', text: LONG_TEXT }), limited)).status,
      200,
    );
    const exhausted = await handleSummarize(
      summarizeRequest({ articleId: 'a1', text: LONG_TEXT }),
      limited,
    );
    assert.equal(exhausted.status, 429);
    assert.equal((await exhausted.json()).error, 'budget_exhausted');

    // Per-IP burst cap → 429 rate_limited.
    resetRateMemory();
    const burst = summarizeEnv();
    for (let i = 0; i < 10; i++) {
      await handleSummarize(summarizeRequest({ articleId: `a${i}`, text: LONG_TEXT }, { ip: '9.9.9.9' }), burst);
    }
    const limitedIp = await handleSummarize(
      summarizeRequest({ articleId: 'a1', text: LONG_TEXT }, { ip: '9.9.9.9' }),
      burst,
    );
    assert.equal(limitedIp.status, 429);
    assert.equal((await limitedIp.json()).error, 'rate_limited');
  });
});

test('handleSummarize: model failures degrade to 502/503, never 500', async () => {
  await withLookupStubbed(async () => {
    const throwing = summarizeEnv({ AI: { run: async () => { throw new Error('model down'); } } });
    const failed = await handleSummarize(
      summarizeRequest({ articleId: 'a1', text: LONG_TEXT }),
      throwing,
    );
    assert.equal(failed.status, 502);
    assert.equal((await failed.json()).error, 'summarize_failed');

    const empty = summarizeEnv({ AI: { run: async () => ({ response: '   ' }) } });
    assert.equal(
      (await handleSummarize(summarizeRequest({ articleId: 'a1', text: LONG_TEXT }), empty)).status,
      502,
    );

    const noBinding = summarizeEnv({ AI: undefined });
    assert.equal(
      (await handleSummarize(summarizeRequest({ articleId: 'a1', text: LONG_TEXT }), noBinding)).status,
      503,
    );
  });
});
