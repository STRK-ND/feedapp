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
  rowMatchesCategories,
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
  assert.deepEqual(p, { page: 1, pageSize: 50, q: '', since: 0, until: 0, category: '', sources: [], sort: 'date_desc' });

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
