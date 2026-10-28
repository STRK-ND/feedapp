// The worker's HTTP contract, verified over e2e on the tools-only target.
// Mirrors tool/api-contract.sh so the same facts are asserted by the runner:
// `node workers/dev-server.mjs` must be running, or set
// CURATED_FEEDS_WORKER_URL to another base (the live worker, a preview).
//
// On a tools-only target there is no app.baseUrl, so the URL is read here.
import { describe, test, expect } from 'e2e';

const BASE = (process.env.CURATED_FEEDS_WORKER_URL ?? 'http://127.0.0.1:8791').replace(/\/$/, '');
const API_SECRET = process.env.CURATED_FEEDS_API_SECRET ?? 'local-api-secret';
const ADMIN_SECRET = process.env.CURATED_FEEDS_ADMIN_SECRET ?? 'local-admin-secret';
const app = { 'content-type': 'application/json', 'x-api-secret': API_SECRET };
const admin = { 'content-type': 'application/json', 'x-api-secret': ADMIN_SECRET };

const call = (method: string, path: string, headers: Record<string, string> = {}, body?: unknown) =>
  fetch(new URL(path, BASE), {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });

// Device tests live on the android target; these belong to the api target only.
describe('worker contract', { platforms: ['api'] }, () => {
  test('health and public reads answer', async () => {
    const health = await call('GET', '/health');
    expect(health.status).toBe(200);
    expect((await health.json()) as { ok: boolean }).toMatchObject({ ok: true });
    await expect((await call('GET', '/articles')).status).toBe(200);
    await expect((await call('GET', '/sources')).status).toBe(200);
  });

  test('unknown routes and wrong methods fall through to 404', async () => {
    await expect((await call('GET', '/')).status).toBe(404);
    await expect((await call('GET', '/nope')).status).toBe(404);
    await expect((await call('POST', '/articles', { 'content-type': 'application/json' }, {})).status).toBe(404);
    await expect((await call('OPTIONS', '/articles')).status).toBe(204);
  });

  test('filters narrow the feed and report page metadata', async () => {
    const paged = await call('GET', '/articles?page=1&pageSize=2');
    const page1 = (await paged.json()) as { items: { id: string }[]; total: number; hasMore: boolean };
    expect(page1.items).toHaveLength(2);
    expect(page1.items.length).toBeLessThanOrEqual(page1.total);

    const pastEnd = (await (await call('GET', '/articles?page=999')).json()) as { items: unknown[]; hasMore: boolean };
    expect(pastEnd.items).toEqual([]);
    expect(pastEnd.hasMore).toBe(false);

    // Invariants, not counts: `total` is the matching count, `items` the page.
    const verge = (await (await call('GET', '/articles?source=verge')).json()) as { items: { sourceId: string }[]; total: number; hasMore: boolean };
    expect(verge.items.every(article => article.sourceId === 'verge')).toBe(true);
    expect(verge.items.length).toBe(Math.min(50, verge.total));
    expect(verge.hasMore).toBe(verge.total > verge.items.length);

    const missing = (await (await call('GET', '/articles?source=__nope__')).json()) as { items: unknown[]; total: number };
    expect(missing.items).toEqual([]);
    expect(missing.total).toBe(0);

    const ascending = (await (await call('GET', '/articles?sort=date_asc')).json()) as { items: { pubDate: number }[] };
    const dates = ascending.items.map(article => article.pubDate);
    expect([...dates].sort((a, b) => a - b)).toEqual(dates);
  });

  test('app-level routes fail closed with no secret', async () => {
    await expect((await call('GET', '/articles/refresh')).status).toBe(401);
    await expect((await call('POST', '/subscribe', { 'content-type': 'application/json' }, { token: 'abcdefghijklmnop' })).status).toBe(401);
    await expect((await call('PUT', '/sources', { 'content-type': 'application/json' }, { sources: [] })).status).toBe(401);
  });

  test('the app secret reaches subscribe and refresh but not source overrides', async () => {
    await expect((await call('GET', '/articles/refresh', app)).status).toBe(200);
    await expect((await call('POST', '/subscribe', app, { token: 'abcdefghijklmnop' })).status).toBe(200);
    await expect((await call('DELETE', '/subscribe', app, { token: 'abcdefghijklmnop' })).status).toBe(200);
    await expect((await call('POST', '/subscribe', app, {})).status).toBe(400);
    // Admin authority is the same header with a different secret: an app
    // secret must not rewrite the canonical list for every user.
    await expect((await call('PUT', '/sources', app, { sources: [] })).status).toBe(401);
  });

  test('admin authority overrides the source list, and an empty list is refused', async () => {
    await expect((await call('PUT', '/sources', admin, { sources: [] })).status).toBe(400);
    const override = await call('PUT', '/sources', admin, {
      sources: [{ id: 'verge', name: 'The Verge', url: 'https://www.theverge.com/rss/index.xml', category: 'Tech' }],
    });
    await expect(override.status).toBe(200);
    const sources = (await (await call('GET', '/sources')).json()) as { sources: { name: string }[] };
    expect(sources.sources).toHaveLength(1);
    expect(sources.sources[0].name).toBe('The Verge');
  });
});
