// Counts Cloudflare KV round-trips the real worker performs per request.
// Local latency cannot see network, but each KV get is one round trip a real
// deployment pays — this is the proxy that matters.
//
//   node tool/api-kv-ops.mjs [--port 8811] [--seed 269]
import { createServer } from 'node:http';
import worker, { ARTICLES_CACHE_KEY, SOURCES_OVERRIDE_KEY } from '../workers/feed-worker.js';
import { SOURCES } from '../workers/feed-worker.js';

const args = process.argv.slice(2);
const flag = (n, d) => { const i = args.indexOf(`--${n}`); return i !== -1 && args[i + 1] ? args[i + 1] : d; };
const port = Number(flag('port', '8811'));
const seedCount = Number(flag('seed', '269'));
const BASE = `http://127.0.0.1:${port}`;

const sourceNames = ['The Verge', 'Wired', 'BBC World', 'Ars Technica', 'TechCrunch', 'Hacker News'];
const seeded = Array.from({ length: seedCount }, (_, i) => ({
  id: `verge-${i}`, sourceId: 'verge', sourceName: sourceNames[i % sourceNames.length],
  title: `Seeded article number ${i} about the hinge`,
  description: 'A realistic-length description so payload sizes are real. '.repeat(2),
  pubDate: 1_700_000_000_000 - i * 60_000, category: i % 2 ? 'Tech' : 'News', imageUrl: null,
}));

// Operation counters, reset around each measured request.
const counts = { get: 0, put: 0, delete: 0, list: 0 };
function countingKV() {
  const map = new Map(Object.entries({ [ARTICLES_CACHE_KEY]: JSON.stringify(seeded), [SOURCES_OVERRIDE_KEY]: JSON.stringify(SOURCES) }));
  return {
    async get(k, type) { counts.get++; const v = map.get(k); return v === undefined ? null : type === 'json' ? JSON.parse(v) : v; },
    async put(k, v) { counts.put++; map.set(k, String(v)); },
    async delete(k) { counts.delete++; map.delete(k); },
    async list() { counts.list++; return { keys: [...map.keys()].map(name => ({ name })) }; },
  };
}

const env = { ARTICLES_KV: countingKV(), API_SECRET: 'local-api-secret', ADMIN_SECRET: 'local-admin-secret' };
const ctx = { waitUntil: () => {} };

const server = createServer(async (req, res) => {
  const url = new URL(req.url, BASE);
  const chunks = []; for await (const c of req) chunks.push(c);
  const body = chunks.length ? Buffer.concat(chunks) : undefined;
  const headers = new Headers();
  for (const [k, v] of Object.entries(req.headers)) headers.set(k, Array.isArray(v) ? v.join(', ') : String(v));
  if (!headers.has('CF-Connecting-IP')) headers.set('CF-Connecting-IP', '127.0.0.1');
  const request = new Request(url, { method: req.method, headers, body: body && !['GET', 'HEAD'].includes(req.method) ? body : undefined });
  counts.get = counts.put = counts.delete = counts.list = 0;
  try {
    const response = await worker.fetch(request, env, ctx);
    const payload = Buffer.from(await response.arrayBuffer());
    res.writeHead(response.status, Object.fromEntries(response.headers));
    res.end(payload);
  } catch (error) {
    res.writeHead(500, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: 'harness_failed', message: String(error) }));
  }
});

server.listen(port, '127.0.0.1', async () => {
  const api = { 'content-type': 'application/json', 'x-api-secret': 'local-api-secret' };
  const cases = [
    ['GET /articles (default)', '/articles'],
    ['GET /articles?page=2', '/articles?page=2'],
    ['GET /articles?source=verge', '/articles?source=verge'],
    ['GET /articles?q=the', '/articles?q=the'],
    ['GET /articles?sort=date_asc', '/articles?sort=date_asc'],
    ['GET /sources', '/sources'],
    ['GET /sources (again, w/ etag)', '/sources'],
    ['GET /articles/refresh', '/articles/refresh'],
    ['POST /subscribe', '/subscribe'],
  ];
  console.log(`KV round-trips per request (seed=${seedCount} articles)\n`);
  for (const [label, path] of cases) {
    counts.get = counts.put = counts.delete = counts.list = 0;
    const method = label.startsWith('POST') ? 'POST' : 'GET';
    const init = { method, headers: api };
    if (method === 'POST') init.body = JSON.stringify({ token: 'abcdefghijklmnop' });
    await fetch(BASE + path, init);
    const total = counts.get + counts.put + counts.delete + counts.list;
    console.log(`${label.padEnd(32)} gets=${String(counts.get).padStart(3)} puts=${String(counts.put).padStart(2)} deletes=${String(counts.delete).padStart(2)} lists=${String(counts.list).padStart(2)}  total=${total}`);
  }
  console.log('\nEach get/put is one edge round trip; total is the per-request cost.');
  server.close();
});
