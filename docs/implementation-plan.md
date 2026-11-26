# Tier 1 implementation plan

Implements the four Tier 1 items from `docs/market-roadmap.md`: mute filters,
teaser-feed full text at ingestion, full-text search, and Pro AI summaries.
Grounded in the current code: `workers/feed-worker.js` (1,034 lines, KV cache,
single refresh pipeline), `lib/services/feed_database.dart` (two payload-blob
tables, v1→v2 migration pattern), `lib/models/filter_params.dart`,
`lib/screens/feed_screen.dart` (client-side substring search at line ~692),
Pro gating via `SettingsNotifier.isPro` + the R-1 paywall entry points.

Release mechanics up front:

- Worker changes deploy independently of the app (`wrangler deploy`); every
  worker change must stay backward-compatible with the shipped 1.2.1 client.
- App changes ship via Shorebird OTA when Dart-only; anything touching the
  Android embedding or native plugins waits for the next Play/direct release.
  All four features are Dart + worker only, so all ship OTA.
- Every feature lands with a regression test in `test/unit/` following the
  existing pattern (behaviour + a pinned regression, as in 1.2.1).

---

## Feature 1 — Mute filters (keyword rules)

**Why first:** cheapest build, no schema change, immediate power-user value;
Inoreader (rules) and Feedly (mute filters) both gate this behind paid tiers.

### Design
A user-managed list of muted terms (case-insensitive substring match against
title + description). Stored as a setting so cloud sync carries it across
devices for free (`_pushSettings`/`_restoreSettings` already serialize the
settings snapshot — add the key to that snapshot's allowlist).

Two enforcement points:
1. **Client (authoritative for display):** filter in the feed screen's list
   build, alongside the existing `_searchQuery` filter. Applies to both the
   Stack and Continuous view modes and the Saved tab is *not* filtered
   (a saved article was a deliberate act).
2. **Worker (bandwidth + push hygiene):** `GET /articles` drops muted matches
   server-side when the client sends `mute=` (comma-separated, clamped like
   the existing `q` param — 200 chars total, 50 terms). Push notifications in
   `refreshArticlesAndMaybeNotify` skip articles matching any subscriber's
   muted terms, so a muted keyword stops buzzing the phone.

### Steps
1. `SettingsService`: `getMutedTerms()` / `setMutedTerms(List<String>)`
   (stored JSON string, key `muted_terms`); normalize to lowercase, dedupe,
   cap 50 terms × 64 chars.
2. `SettingsNotifier`: expose the list + `muteTerm`/`unmuteTerm`; include in
   the sync snapshot (both `_pushSettings` and the restore reject-list check
   in `sync_merge.dart`).
3. `feed_screen.dart`: filter predicate next to the search filter; empty-state
   copy when everything is muted out.
4. `Settings → Feed Settings`: a "Muted keywords" management row (add / remove
   list tiles), reusing the existing settings-card pattern.
5. `FilterParams`: `muted` field → `toQueryParams` emits `mute=`; worker
   `handleArticles` clamps and applies it after the existing `q` filter.
6. Worker: in the notification fan-out, skip articles matching muted terms
   (muted terms travel with the subscription row written by `/subscribe`).
7. Tests: unit tests for normalize/cap, feed filter (muted article hidden,
   saved tab unaffected), worker `mute=` clamp + push skip.

### Risks
- Settings snapshot schema: additive key only; old clients ignore unknown
  keys on restore (verify `sync_merge.dart` tolerance before shipping).
- Worker clamp must mirror the existing L-3 clamps exactly.

---

## Feature 2 — Teaser-feed full text at ingestion

**Why:** the #1 cited reader complaint in the 2026 roundups; the client
already has extraction (`ArticleContentService`) but only per-article on
demand, and the worker deliberately stopped emitting `fullContent` (P-1)
because it duplicated `description`. This feature makes `fullContent` mean
something again: *extracted* body text, present only when the feed was a
teaser.

### Design
During worker ingestion, when an item's `description` is shorter than a
threshold (start: 400 visible chars after `strip()`), fetch the item link and
extract the article text with the same tag rules the client uses
(`descTag`/`fullContentTag` chain already exists in the worker's parser —
extend it with a readability-style main-content pass: largest text density
under `article`/`main`/`[role=main]`, falling back to the existing tag chain).

Budget guards (the refresh must never blow up or hang):
- Cap extraction at N items per refresh cycle (start: 25, oldest-last so new
  items get priority), cap per-item fetch at 8 s / 512 KB, and store extracted
  text truncated at ~32 KB.
- Failures are silent: store nothing, the client falls back to `description`
  exactly as the P-1 fallback already does.
- Reuse the refresh lock; extraction happens inside the existing single
  refresh pipeline before the KV cache write, so the cache stays atomic.

Client side: `Article.fromJson` already reads `fullContent`; the reader
prefers non-empty `fullContent` over `description` (P-1 fallback is already
shipped in 1.0.2). The only client change is a "fetched full text" source
badge on the article card so a power reader can trust the body.

### Steps
1. Worker: extraction helper (fetch + main-content pass + truncation) with
   its own unit tests in `workers/test` (teaser → extracted; full article →
   untouched; timeout/oversize → description only).
2. Wire into `refreshArticlesAndMaybeNotify` with the per-cycle cap; keep the
   future-dated and dedupe checks unchanged (extraction runs after dedupe so
   retries don't re-fetch).
3. Emit `fullContent` only when it differs materially from `description`
   (length ratio > 1.5), keeping payloads small — the P-1 finding was about
   waste, don't reintroduce it.
4. Client: badge on the expanded card; no model change needed.
5. Tests: worker fixtures for each branch; client test pinning the badge and
   the reader preference order.

### Risks
- Publisher blocking/UA rules: set a browser-like UA, honour 403/429 by
  skipping the source for that cycle (never hammer a 429-ing host).
- Cache size: 32 KB cap × capped items keeps the KV payload within its 25 MB
  value limit with wide margin; measure the refresh duration delta before
  raising the per-cycle cap.

---

## Feature 3 — Full-text search (SQLite FTS5)

**Why:** Inoreader gates body search behind a paid tier; the local bodies are
already cached, so offline full-text search is nearly free — and it is a
natural Pro lever.

### Design
FTS5 virtual tables mirroring `articles` and `saved_articles`, indexed over
title + description + fullContent extracted from each row's JSON payload.
Schema v2→v3 migration (the `migrate` pattern already exists), plus a
background rebuild guarded by the existing idempotent-create guard so a crash
mid-migration leaves a rebuildable state.

Search UI: the existing search field in the feed app bar switches from the
substring filter to an FTS5 `MATCH` query when the query has no results in
the title-only pass (progressive: instant title hits first, body hits
underneath, marked "in article body"). Saved tab searches the saved table.

Pro gating: title search stays free; body search (the FTS pass) is Pro, with
the R-1 pattern — a locked result routes to the paywall with the 5-minute
throttle, and fires `cap_hit`-style analytics (`body_search_locked`).

### Steps
1. `FeedDatabase`: v3 migration creating
   `articles_fts`/`saved_fts` (FTS5, contentless `content=''` with external
   rowid mapping via the `id` column is not available for contentless delete
   — use a regular FTS5 table keyed by article id and rebuild on replace).
   Keep triggers minimal: the repository already funnels every write through
   `replaceFeed`/`saveArticles`, so index maintenance lives in those two
   methods, not in SQL triggers.
2. Repository: `searchBodies(query)` returning ids + snippet, joined back to
   the in-memory snapshot (1.2.1 made the snapshot the source of truth —
   search results must come through it, not a second full-table read).
3. Feed screen: wire the second-pass results into the existing empty-state
   and result-list flow; Pro gate + paywall route + analytics.
4. Migration safety: rebuild runs on first launch after upgrade; if the
   device SQLite lacks FTS5 (rare on API 21+), fall back to the current
   substring search and log — never crash the launch path.
5. Tests: migration v2→v3 (fresh + upgrade paths), index maintained across
   replace/save/delete, snippet correctness, Pro gate, FTS-less fallback.

### Risks
- FTS5 availability on old Android SQLite builds — the fallback above makes
  it a degradation, not a breakage.
- Index rebuild cost on 1,000-row feeds: measure; if slow, rebuild in
  background after splash preload (the preload hook already exists).

---

## Feature 4 — Pro AI summaries (Cloudflare Workers AI)

**Why:** every major competitor gates summaries behind its paid tier
(Inoreader Intelligence, Feedly Leo, NewsNinja+); the one-article triage
screen is exactly where a 2–3 line summary changes the read/skip decision.

### Design
New authenticated worker route `POST /summarize` (joins `/subscribe` and
`/articles/refresh` behind the existing app-level guard):

- Body: `{ articleId, url, text }` — the client sends the already-extracted
  body (from Feature 2's `fullContent` or its own `ArticleContentService`
  fetch), truncated to ~8k chars. The worker never re-fetches.
- Model: a Workers AI summarization model (`@cf/...` summarization class),
  prompt: 3 bullet points, ≤60 words, same language as the input.
- Entitlement: requires the caller's auth token; Pro check via the
  account-level `isPro` flag (the sole-writer rule from M-1/F-2 stays).
- Budget: per-uid monthly token/character counter in KV keyed
  `summarize:{uid}:{yyyy-mm}`, with a 30-day TTL; over budget → 429 with a
  friendly message pointing at the paywall. Free users get a small monthly
  trial allowance (e.g. 5 summaries) as the conversion hook — mirrors
  Inoreader's token-metering model.
- Rate limit: per-IP + per-uid via the existing KV limiter (documented
  advisory overshoot); responses carry the same security headers as the other
  routes.

Client:
- `SummarizeService`: POST + cached result (cache keyed by article id in the
  article payload or a small side table; summaries are immutable per text).
- Expanded card: "Summarize" action under the title (Inoreader's proven
  placement); result renders in the reader typography, with copy + dismiss.
- States: loading shimmer, error with retry, locked (free user past trial →
  paywall route with the R-1 throttle), over-budget message.
- Analytics: `summary_requested`, `summary_shown`, `summary_error`,
  `summary_locked` — extending the R-3 funnel events.

### Steps
1. Worker: route + guard + clamp + limiter + KV budget counter; unit tests
   for auth, budget expiry, 429 paths, and clamping (mirror L-3 style).
2. Bind the Workers AI binding in `wrangler.toml`; measure p50/p95 latency on
   real article lengths before finalizing the truncation cap.
3. Client: service + cache + card action + paywall routing + analytics.
4. Ship the worker first (no-op for old clients), then the app via OTA.

### Risks
- Workers AI quality/latency for long inputs — the truncation cap and the
  bullet-point prompt keep it predictable; if quality disappoints the design
  leaves the provider swappable behind the route.
- Cost: per-uid budget caps worst-case spend; the trial allowance is the
  only free exposure.

---

## Sequence and milestones

| # | Feature | Worker | App (OTA) | Est. size |
|---|---------|--------|-----------|-----------|
| 1 | Mute filters | small (param + push skip) | medium (settings UI + filter) | ~1–2 days |
| 2 | Teaser full text | medium (extraction + caps) | small (badge) | ~2–3 days |
| 3 | FTS search | none | medium (migration + UI + gate) | ~2–3 days |
| 4 | AI summaries | medium (route + budget) | medium (service + card) | ~3–4 days |

Order matters: 1 and 2 are independent and can land in one release; 3 is
independent but touches the DB, so it lands alone with extra test soak; 4
depends on nothing but lands last so its analytics funnel measures users who
already have 1–3. Worker changes for all four can ship ahead of the app
(they are all backward-compatible).

Metrics to watch after each release (PostHog, existing funnel): muted-term
adoption (`settings` snapshot contains terms), % articles served with
extracted full text (worker log counter), body-search usage + conversion at
the paywall, `summary_requested` → `purchase_completed`.
