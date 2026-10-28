// Serves the real worker over local HTTP so its contract can be exercised
// with curl (and by e2e) without wrangler, a Cloudflare account, or network.
//
//   node workers/dev-server.mjs [--port 8787] [--api-secret s] [--admin-secret a]
//
// The env is an in-memory KV stub plus a seeded article cache, so every route
// answers deterministically and offline. Reads see the seeded feed; the app
// routes see the same seeded source list.
import { createServer } from 'node:http';
import worker, { ARTICLES_CACHE_KEY, SOURCES_OVERRIDE_KEY } from './feed-worker.js';
import { SOURCES } from './feed-worker.js';

const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
};

const port = Number(flag('port', process.env.PORT ?? '8787'));
const apiSecret = flag('api-secret', process.env.API_SECRET ?? 'local-api-secret');
const adminSecret = flag('admin-secret', process.env.ADMIN_SECRET ?? 'local-admin-secret');
const seedCount = Number(flag('seed', process.env.CURATED_FEEDS_SEED ?? '269'));

// Deterministic seeded feed sized like the live cache, descending dates so the
// default sort is already correct and the cache path is exercised. The live
// worker held 269 articles on 2026-10-28; the flag scales the load.
// Sources cycle so a `?source=` filter actually has to narrow the set.
const seedSources = ['verge', 'wired', 'bbc', 'ars', 'techcrunch'];
const sourceNames = ['The Verge', 'Wired', 'BBC World', 'Ars Technica', 'TechCrunch'];
const seeded = Array.from({ length: seedCount }, (_, index) => ({
  id: `${seedSources[index % seedSources.length]}-${index}`,
  sourceId: seedSources[index % seedSources.length],
  sourceName: sourceNames[index % sourceNames.length],
  title: index === 0 ? 'Hinge report' : `Seeded article number ${index} about the hinge`,
  description:
    'A realistic-length description so JSON parsing and text filtering are measured against real payload sizes rather than a toy string. '.repeat(
      2,
    ),
  pubDate: 1_700_000_000_000 - index * 60_000,
  category: index % 2 ? 'Tech' : 'News',
  imageUrl: null,
}));

function kvStub(initial) {
  const map = new Map(Object.entries(initial));
  return {
    async get(k, type) {
      const v = map.get(k);
      if (v === undefined) return null;
      return type === 'json' ? JSON.parse(v) : v;
    },
    async put(k, v) { map.set(k, String(v)); },
    async delete(k) { map.delete(k); map.delete(k); },
    async list() { return { keys: [...map.keys()].map(name => ({ name })) }; },
  };
}

const env = {
  ARTICLES_KV: kvStub({ [ARTICLES_CACHE_KEY]: JSON.stringify(seeded), [SOURCES_OVERRIDE_KEY]: JSON.stringify(SOURCES) }),
  API_SECRET: apiSecret,
  ADMIN_SECRET: adminSecret,
};

const ctx = { waitUntil: () => {} };

// Only the loopback source IP is allowed to act as the caller, so a stray
// request from outside the host cannot collide with the seeded data.
const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${port}`);
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const body = chunks.length ? Buffer.concat(chunks) : undefined;
  const headers = new Headers();
  for (const [k, v] of Object.entries(req.headers)) headers.set(k, Array.isArray(v) ? v.join(', ') : String(v));
  headers.set('CF-Connecting-IP', '127.0.0.1');

  const request = new Request(url, {
    method: req.method,
    headers,
    body: body && !['GET', 'HEAD'].includes(req.method) ? body : undefined,
  });

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

server.listen(port, '127.0.0.1', () => {
  console.log(`worker dev server on http://127.0.0.1:${port} (api-secret=${apiSecret}, admin-secret=${adminSecret})`);
});
