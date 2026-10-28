// A/B latency harness: the worker at HEAD (KV read+write per request) against
// the working tree (per-isolate counter), both driven over local HTTP with a
// simulated KV round-trip so the difference is measured, not asserted.
//
//   node tool/api-ab.mjs [--kv-latency 5] [--seed 269] [--requests 60]
//
// Local CPU latency cannot see a network, so each KV get/put is delayed by
// --kv-latency to model a Cloudflare edge round trip. Every request's ops are
// counted too, so the score is attributable.
import { createServer } from 'node:http';
import { execFileSync } from 'node:child_process';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

// The comparison baseline is the worker as committed (HEAD), so the tool
// reproduces the "before" itself from git rather than needing a stashed copy.
const ROOT = path.resolve(import.meta.dirname, '..');
const oldSource = execFileSync('git', ['show', 'HEAD:workers/feed-worker.js'], { cwd: ROOT, encoding: 'utf8' });
const oldDir = mkdtempSync(path.join(tmpdir(), 'worker-head-'));
const oldPath = path.join(oldDir, 'feed-worker.js');
writeFileSync(oldPath, oldSource);

const args = process.argv.slice(2);
const flag = (n, d) => { const i = args.indexOf(`--${n}`); return i !== -1 && args[i + 1] ? args[i + 1] : d; };
const KV_LATENCY = Number(flag('kv-latency', '5'));
const SEED = Number(flag('seed', '269'));
const REQUESTS = Number(flag('requests', '60'));
const API = { 'content-type': 'application/json', 'x-api-secret': 'local-api-secret' };

const oldWorker = (await import(oldPath)).default;
const newWorker = (await import('../workers/feed-worker.js')).default;

const sourceNames = ['The Verge', 'Wired', 'BBC World', 'Ars Technica', 'TechCrunch'];
const seeded = Array.from({ length: SEED }, (_, i) => ({
  id: `verge-${i}`, sourceId: 'verge', sourceName: sourceNames[i % sourceNames.length],
  title: `Seeded article number ${i} about the hinge`,
  description: 'A realistic-length description so payload sizes are real. '.repeat(2),
  pubDate: 1_700_000_000_000 - i * 60_000, category: i % 2 ? 'Tech' : 'News', imageUrl: null,
}));

const sleep = ms => new Promise(r => setTimeout(r, ms));

// One server per worker so the two per-isolate counters start empty.
async function serve(worker, port) {
  const store = new Map(Object.entries({ 'articles:v1': JSON.stringify(seeded), 'config:sources': JSON.stringify([]) }));
  const ops = { get: 0, put: 0 };
  const kv = {
    async get(k, type) { ops.get++; await sleep(KV_LATENCY); const v = store.get(k); return v === undefined ? null : type === 'json' ? JSON.parse(v) : v; },
    async put(k, v) { ops.put++; await sleep(KV_LATENCY); store.set(k, String(v)); },
    async delete(k) { await sleep(KV_LATENCY); store.delete(k); },
    async list() { await sleep(KV_LATENCY); return { keys: [...store.keys()].map(name => ({ name })) }; },
  };
  const env = { ARTICLES_KV: kv, API_SECRET: 'local-api-secret', ADMIN_SECRET: 'local-admin-secret' };
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, `http://127.0.0.1:${port}`);
    const chunks = []; for await (const c of req) chunks.push(c);
    const body = chunks.length ? Buffer.concat(chunks) : undefined;
    const headers = new Headers();
    for (const [k, v] of Object.entries(req.headers)) headers.set(k, Array.isArray(v) ? v.join(', ') : String(v));
    if (!headers.has('CF-Connecting-IP')) headers.set('CF-Connecting-IP', '127.0.0.1');
    const request = new Request(url, { method: req.method, headers, body: body && !['GET', 'HEAD'].includes(req.method) ? body : undefined });
    try {
      const response = await worker.fetch(request, env, { waitUntil: () => {} });
      const payload = Buffer.from(await response.arrayBuffer());
      res.writeHead(response.status, Object.fromEntries(response.headers));
      res.end(payload);
    } catch (error) {
      res.writeHead(500, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: String(error) }));
    }
  });
  await new Promise(r => server.listen(port, '127.0.0.1', r));
  return { server, ops, close: () => server.close() };
}

const routes = ['/articles', '/articles?page=1&pageSize=100', '/articles?source=verge', '/articles?q=the', '/articles?sort=date_asc', '/sources'];

async function measure(worker, port) {
  const base = `http://127.0.0.1:${port}`;
  // Warm up so JIT cost is not charged to whichever worker runs first. Every
  // warm-up request also needs its own caller (see `call`).
  for (const path of routes) for (let i = 0; i < 25; i++) await call(base, path);
  const result = {};
  for (const path of routes) {
    const times = [];
    for (let i = 0; i < REQUESTS; i++) {
      const t = process.hrtime.bigint();
      const status = await call(base, path);
      times.push(Number(process.hrtime.bigint() - t) / 1e6);
      if (status !== 200) throw new Error(`unexpected ${status} for ${path}`);
    }
    times.sort((a, b) => a - b);
    result[path] = { p50: times[Math.floor(times.length * 0.5)], p95: times[Math.floor(Math.floor(times.length * 0.95))] };
  }
  return result;
}

// Real clients repeat: a handful of caller IPs, each polling the same server
// many times — exactly what the app does. A single shared IP would hit the
// worker's own 120/min limit and make the comparison meaningless, while a
// unique IP per request never reuses a limiter bucket and hides the win.
// CLIENT_COUNT clients keep every one of them well under the limit.
let caller = 0;
const CLIENTS = Number(flag('clients', '8'));
const call = (base, path) => {
  caller++;
  const client = (caller % CLIENTS) + 1;
  return fetch(base + path, { headers: { ...API, 'CF-Connecting-IP': `10.0.0.${client}` } }).then(r => r.status);
};

const PORTS = { old: 8831, new: 8832 };
const oldSrv = await serve(oldWorker, PORTS.old);
const newSrv = await serve(newWorker, PORTS.new);

const before = await measure(oldWorker, PORTS.old);
const after = await measure(newWorker, PORTS.new);

// Per-route KV ops: one fresh caller per measurement, and the steady-state
// count is taken after a second identical call from the same fresh caller
// (so any first-call seeding is included once, not confused as steady state).
const countOps = async (port, path) => {
  const srv = port === PORTS.old ? oldSrv : newSrv;
  srv.ops.get = srv.ops.put = 0;
  await call(`http://127.0.0.1:${port}`, path);
  await call(`http://127.0.0.1:${port}`, path);
  return srv.ops.get + srv.ops.put;
};

console.log(`A/B with ${KV_LATENCY}ms simulated KV round-trip, ${SEED} seeded articles, ${REQUESTS} requests per route\n`);
console.log(`${'route'.padEnd(30)} ${'old p50'.padStart(10)} ${'new p50'.padStart(10)} ${'delta'.padStart(10)} ${'old KV'.padStart(8)} ${'new KV'.padStart(8)}`);
console.log('-'.repeat(80));
for (const path of routes) {
  const oldOps = await countOps(PORTS.old, path);
  const newOps = await countOps(PORTS.new, path);
  const d = after[path].p50 - before[path].p50;
  console.log(
    `${path.padEnd(30)} ${before[path].p50.toFixed(2).padStart(8)}ms ${after[path].p50.toFixed(2).padStart(8)}ms ${(d >= 0 ? '+' : '') + d.toFixed(2) + 'ms'} ${String(oldOps).padStart(8)} ${String(newOps).padStart(8)}`,
  );
}

oldSrv.close(); newSrv.close();
