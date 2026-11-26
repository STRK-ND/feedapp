# Changelog

All notable changes to Curated Feeds will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Saved-collection notes + Markdown export (market roadmap Tier 2,
  feature 5):** a Note action on saved articles in the reader (hidden for
  unsaved ones — notes belong to the Saved collection); the note lives
  in the article payload, so cloud sync carries it across devices with
  no schema work. An "Export saved articles" menu item on the Saved tab
  shares the whole collection as Markdown (title, source, date, link,
  note as blockquotes) with injection-safe content cleaning — a title or
  note line can never forge headings or lists inside the export.
  `saved_export` analytics event with the article count. Regression:
  `test/unit/utils/saved_export_test.dart` (format, notes, injection
  safety, userNote payload roundtrip incl. legacy rows) and the note
  dialog test in `test/unit/widgets/expanded_article_card_test.dart`.
- **Pro AI summaries (market roadmap Tier 1, feature 4):** a "Summarize
  with AI" action on the reader card (3 bullets, ≤60 words, article's own
  language) served by a new worker route `POST /summarize` on the
  Cloudflare Workers AI binding (`@cf/meta/llama-3.1-8b-instruct`). Auth
  model: the shared API_SECRET ships in the APK (M-2: effectively
  public), so budget keying never trusts client identity — callers
  present a Firebase ID token verified via the Identity Toolkit lookup
  (Web API key, public by design; KV-cached 55 min; fail closed when
  `FIREBASE_API_KEY` is unset) and the REAL uid keys the monthly budget
  (`summarize:{uid}:{yyyy-mm}`, default 50/month, get-then-put advisory
  per the L-1 KV caveat) with per-IP (10/min) and per-uid (6/min) rate
  limits. Bodies are clamped to 8 000 chars client-side; the worker
  re-clamps and rejects bodies under 200 chars. Client: summaries are
  cached in memory and a new `summaries` SQLite table (schema v3→v4) so
  a summary bought with budget once is never bought again; free users
  get a 5/month trial in the UI, past which the demonstrated intent
  routes to the paywall (`ai_summary` entry, `summary_requested/shown/
  error/locked` analytics). Regression:
  `test/unit/services/summarize_service_test.dart` (body selection,
  trial counter, cache-before-network, response mapping) and
  `test/unit/widgets/summary_gate_test.dart` (trial gate → paywall,
  Pro path, trial tick); the `/summarize` group in
  `workers/test/feed-worker.test.js` (auth fail-closed, lookup caching,
  budget, clamps, model-failure degradation).
- **Full-text body search (market roadmap Tier 1, feature 3):** SQLite FTS5
  virtual tables over title + description + extracted body, schema v2→v3
  with a one-time backfill of existing rows. Index maintenance lives in
  the write methods (save/upsert/saveSaved/markUnsaved/clear), not SQL
  triggers. Search runs on the debounced query as a second pass: instant
  title hits first, body hits merged underneath under an "Also matching
  inside article bodies" banner. Pro-gated per the market plan: free
  users see the match count with a locked teaser routing to the paywall
  (`body_search` entry, `body_search_locked` analytics); devices whose
  SQLite lacks FTS5 silently keep the substring search. Regression:
  `test/unit/services/feed_database_fts_test.dart` (indexing, multi-term
  quoting, per-table scope, reindexing, migration backfill) and
  `test/unit/screens/feed_body_search_test.dart` (free/Pro/no-match
  gates).
- **Teaser-feed full text at ingestion (market roadmap Tier 1, feature 2):**
  many feeds ship only a headline + one sentence; the worker now fetches
  the article page server-side and extracts the main text for genuinely-new
  teaser items (body < 400 chars), so the reader shows the whole story with
  no client fetch. Guards: 25 items/cycle in batches of 5, 8 s timeout and
  512 KB page cap per fetch, extracted text capped at 12 KB, and the body
  is attached only when it is materially longer than the teaser (> 1.5×);
  every failure is a silent skip — the client falls back to the teaser
  body it already has. A hard shed guard keeps the serialized KV cache
  under 20 MB by dropping extracted bodies oldest-first. The expanded card
  shows a "Full text" badge when the body was server-extracted, and the
  reader keeps preferring `fullContent` over the teaser (pre-existing
  P-1 fallback). Regression: the extraction group in
  `workers/test/feed-worker.test.js` (extraction heuristics, attach rule,
  shed guard, fetch failure paths) and
  `test/unit/widgets/expanded_article_card_test.dart` (badge + no client
  fetch when the body is already present).
- **Mute filters (market roadmap Tier 1, feature 1):** a user-managed list of
  muted keywords hides matching articles from the feed tab. Stored in
  `SettingsService` (`muted_terms`), normalized by the shared contract in
  `lib/utils/mute_filter.dart` (trim/lowercase/dedupe, 50 terms × 64 chars,
  commas split terms), synced via the settings snapshot, and enforced at
  three points: the feed screen's filter (Saved tab deliberately exempt),
  the worker's `GET /articles` via a clamped `mute=` query param, and the
  push fan-out — subscription rows carry `preferences.mutedTerms` and
  `matchingTokens` skips tokens whose muted terms match a fresh article.
  Managed from Settings → Feed Settings → Muted keywords; every add/remove
  re-POSTs the push subscription so the server-side row mirrors without
  waiting for the next app launch. Regression: `test/unit/utils/mute_filter_test.dart`,
  the muted-terms groups in `test/unit/services/settings_service_test.dart`,
  `test/unit/providers/muted_terms_test.dart`, the two mute tests in
  `test/unit/screens/feed_launch_read_test.dart`, and the mute cases in
  `workers/test/feed-worker.test.js` (param clamping, `applyFilters`,
  `rowClearsMutes`, `matchingTokens` skip).

## [1.2.1] - 2026-11-01

Hotfix release: Settings touch feedback and two local-read optimizations.

### Performance
- **Settings no longer decodes the whole feed to count it:** the screen's storage card and its "Clear cache" confirmation only need row counts, but `_loadSettings` called `loadArticles()` and `loadSavedArticles()` — reading every row and JSON-decoding every multi-KB payload (including `fullContent`) to take `.length`. Counting now goes straight to the database's row count via new `StorageService.countArticles()` / `countSavedArticles()` (over `FeedDatabase.countArticles()` / `countSavedArticles()`), one `COUNT(*)` per table with no payload decoding. The counts remain storage-accurate rather than snapshot-derived: the repository's in-memory list is capped at the user's `maxArticles`, and a row whose payload fails to decode is still a row that a clear deletes, so the dialog's promise stays exact. Regression: `test/unit/services/storage_service_test.dart` pins counts matching rows, count-stays-exact-when-a-payload-is-undecodable, saved-table counts, empty tables, and `clearFeedCache` zeroing only the feed count
- **Cold launch no longer decodes the local feed twice:** the feed screen read `articles` and `saved_articles` straight from `StorageService` even though the splash preload had just validated the same rows into `ArticleRepository`'s process snapshot. Every cold launch therefore ran two identical full-table reads plus a JSON-decoding pass over every payload twice — 1,540 decodes at the default 500-article setting and 3,080 at the 1,000-row cap, against 520 and 1,040 necessary — for rows the harness verified byte-identical. The screen now sources its local feed through the repository, the owner of that validated snapshot: one read and one decode pass per table. On the same seeded inputs the duplicate screen-load phase measured ~17 ms at the default setting and ~16 ms at the cap (whole launch ~66 ms → ~51 ms on one run; single-run wall time on one host is not a stable figure). Cloud-sync restores and the Saved-tab pull-to-refresh pass `forceRefresh: true` so they revalidate against storage rather than serving the snapshot; a failed local read keeps the previous list on screen instead of blanking it. Regression: `test/unit/screens/feed_launch_read_test.dart` pins one read per table per launch, the filtered render, and the forced-revalidation paths

### Fixed
- **Interactive Settings rows give touch feedback again:** every tap-and-hold row in Settings — alert categories, manage sources, reader preferences, clear cache, open-source licenses, support the app, report bug — answered the tap but painted no ripple. `_buildSettingsCard` groups its tiles in a `Container` whose `BoxDecoration` fill is translucent (`surfaceContainerHighest` at alpha 0.30), and `ListTile` paints its background and ink splashes on the nearest `Material` ancestor, which is *above* that fill; the card wash therefore covered the tile's own `InkDecoration` and splash. Measured on the ink host, the row's paint surface was 43 render-object levels above the card's fill before the fix and 3 after. The card now hosts a `MaterialType.transparency` child (with the card's own 16px radius and no clipping), which becomes that nearest ancestor so splashes paint inside the card instead of behind its background. Regression: `test/unit/screens/settings_tap_feedback_test.dart` walks the whole settings list and fails if any interactive row has a background `ColoredBox`/`DecoratedBox` between it and its `Material`

### Changed
- **Store screenshot project state:** the `android-7` and `android-10` template decks are removed from `app-store-screenshots.json`. Curated Feeds has no tablet layout, and the decks referenced phone captures, so any export from them would have been letterboxed phone art. The Play listing uses the 8-slide phone deck only; the iOS, Mac, TV, Watch, CarPlay, Duo and feature-graphic decks still hold template samples.

## [1.2.0] - 2026-10-18

### Fixed
- **Feed app bar no longer overflows on narrow screens:** the AppBar `actions` row has no scroll and `mainAxisSize.min`, so its children never shrank — with an unread count the labelled "Mark all as read" button plus the count chip, refresh, search and overflow menu overflowed by up to 192px at 320dp (152px at 360, 100px at 412, 32px at 480; clean from 600dp up). The action and the count chip are now `Flexible` and the label ellipsizes, so the bar always fits. Regression: `test/unit/screens/feed_app_bar_overflow_test.dart` renders the screen at 320/360/412/480/600dp and fails on any `RenderFlex overflowed`

## [1.0.2] - 2026-10-14

First over-the-air release. Remediation of the 2026-10-07 security & functional audit
(`burp-audite.md`) — all four passes. Findings are referenced by the audit's IDs.
Supersedes 1.0.1, which was never published to GitHub Releases, so no OTA update has
been available to installed users before this tag.

### Fixed
- **F-1 (data loss):** saved articles are no longer silently deleted. `saveArticles` never evicts a row the Saved list still references, and the cloud-sync rebuild now unions the feed table with rows already in `saved_articles` (rows already orphaned by older builds are kept too)
- **M-1 + F-2 (entitlement):** `is_pro` no longer travels in the synced settings snapshot — that path let a user grant themselves Pro on their own Firestore documents, and let a not-yet-synced device revoke a purchase made elsewhere. The flag is applied only via `CloudSyncService._restoreProFlag` (which holds the Play verified-purchase rule); `settings restore` also hard-rejects the key as defence in depth
- **F-2:** `_pushSettings` no longer rewrites `users/{uid}.isPro` from the local preference; `setPro` is the sole writer of the account-level flag
- **M-2 (worker):** the `/subscribe` and `DELETE /subscribe` rate limits are keyed on the caller IP instead of the caller-supplied token — the old keying allowed unlimited subscription-row creation (the gating secret ships in the APK)
- **P-2:** the automatic update check honours its hourly throttle again (`forceCheck` was defeating it on every cold start); GitHub rate-limit responses (403/429) are logged instead of silently swallowed. Manual check keeps `forceCheck`
- **P-3 (worker):** `/articles` skips the redundant full-array sort when the default `date_desc` order is requested against the unfiltered cache (persisted pre-sorted) — `pageSize=1` no longer costs 90% of `pageSize=50`
- **F-3:** the tombstone map is pruned to 90 days on every sync (`pruneDeletions` existed and was tested but was never wired in)
- **F-5:** the edition counter bump no longer fires the cloud-sync hook — every refresh used to push two byte-identical Firestore documents (~48 pointless writes/day/user)
- **F-6:** the "Max articles: 2000" dropdown option is removed (the storage cap of 1000 made it a silent no-op)
- **L-5:** the flaky paywall test is fixed by its actual root cause: `easeOutBack` overshoot made a derived `Opacity` assert in debug builds (splash screen already had the guard; the paywall was missing it). Analytics failures also no longer propagate out of `initState`
- **P-1 (client):** the reader falls back to `description` when `fullContent` is empty; custom-feed articles no longer duplicate the description into `fullContent`

### Added
- **R-1:** hitting the free saved-articles cap now routes to the paywall (both the swipe and button paths, keeping the 5-minute throttle), as does tapping a locked Pro reader theme — the moment of demonstrated purchase intent no longer dead-ends at a dismissible SnackBar
- **R-2:** in-app account deletion (Play policy requirement): typed-confirmation dialog in Settings → Account; wipes the Firestore mirror (articles, settings, sources, sync state, user doc) before deleting the Firebase Auth record — ordering chosen so a failed wipe can never orphan owned data
- **R-3:** monetisation-funnel analytics: `paywall_shown` (with entry-point trigger), `paywall_action` (open/buy/restore/dismiss), `purchase_completed`, and `cap_hit`
- **R-4:** in-app review prompt (`in_app_review`), requested at most once per 90 days on reader close after a completed read, never for Pro users

### Security (audit hardening, Low severity)
- **Worker:** responses carry `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, and HSTS (L-2), plus `Cache-Control: max-age=60` and an `ETag` with `If-None-Match`/304 support on public GET routes (P-6)
- **Worker:** free-text `q`, `category`, and `source` query params are clamped (200/64 chars, 50 sources) like the numeric params already were (L-3)
- **Worker:** the KV rate limiter is documented as advisory (~10% overshoot under concurrent burst; KV has no compare-and-swap) (L-1)
- **Worker:** `matchingTokens` caps the subscription scan at 2000 rows per cron cycle (P-4), and the announced-marker dedupe reads run in parallel with writes kept serial (P-5)
- **Worker:** `fullContent` is no longer emitted — it was a byte-for-byte copy of `description` in 100/100 measured articles, 26% of every payload (P-1); clients default the field and fall back to `description`
- **Android:** release builds fail closed when `key.properties` is missing instead of silently producing a debug-signed APK; opt back in locally with `-PallowDebugSigning` (L-4)
- **Android:** APKs/AABs build for `arm64-v8a` + `armeabi-v7a` only — dropping the emulator-only `x86_64` ABI removes ~21 MB from every sideload APK (R-5)
- **Notifications (M-3):** a 401 from the worker's `/subscribe` is now surfaced as a high-severity error naming the stale `WORKER_API_SECRET` — that silent failure had disabled push for whole release builds
- **Cloud sync (F-4):** the full `users/{uid}/articles` read on every sync is documented as a known cost (Option A); a structural fix (single-doc triage state) is deliberately deferred until measured

### Security (audit hardening, Informational)
- **Client (I-1):** `debugPrint` is silenced in every release build, not just `play` — `direct` sideload builds leaked worker URLs, auth headers, and error text to a world-readable logcat
- **Client (I-2):** the Play `purchaseToken` is no longer persisted to Firestore; Play's BillingClient is the restore authority, and a redeemable credential is not stored where the user can read it back
- **Client (I-9):** `stableIdForUrl` widened to 53 bits (was 30), and `addCustomSource` now disambiguates colliding ids deterministically — colliding source ids produced colliding SQLite article ids, so two feeds silently overwrote each other's articles

### Changed
- **Feed app bar de-cluttered:** "Mark all read" is now a labeled button instead of an unexplained `done_all` glyph (its icon read as a read-state badge, not an action), the Stack/Continuous view-mode toggle moved to Settings → Feed Settings where it belongs as a persisted preference, and the overflow menu icon becomes `more_horiz` (light `more_vert` reads as a drag handle or dismiss). Feed tab drops from five icon-only actions to refresh / search / menu. The folio amber dot keeps its mark-all-read shortcut for power users, now documented in Semantics as the shortcut it is

## [1.0.0] - 2026-09-27

Play Store first release (versionCode 26, supersedes the sideload 1.0.2+25 line).

### Added
- Distribution flavors: `play` (Google Play; no self-update, no install-packages permission, Play-dictated free tier) and `direct` (GitHub Releases; full OTA self-update)
- Play builds compile with `--dart-define=PLAY_STORE_BUILD=true`; all self-update paths compile out and the update menu entry is hidden
- R8 minification + resource shrinking for release builds, with keep rules for Firebase Messaging, Play Billing, and flutter_local_notifications
- docs/play-store-release.md: store-readiness checklist, build commands, upload flow

### Changed
- Free-tier saved-articles cap is 5 on Play builds (disclosed on the store listing) and 25 on direct builds
- Pro entitlement on Play builds additionally requires a locally verified Play purchase; a cloud Pro flag alone no longer flips Pro there
- Version scheme: Play builds start at 1.0.0+26 so every future Play versionCode outranks the sideload line

### Security (run-2 audit + run-3 release recheck)
- Worker: app-level authorization now fails closed when `API_SECRET` is unset — `/subscribe` and `/articles/refresh` are no longer open by default (reads stay public)
- Worker: subscription tokens are capped at 4096 chars on POST/DELETE `/subscribe`
- Worker: future-dated feed items (>24h ahead) are dropped at ingestion so they cannot pin clients' delta watermarks
- Worker: 500 responses no longer echo exception text to callers
- OTA: in-app updater verifies the APK against the release's `SHA256SUMS` asset (published by CI) before install; mismatch or missing checksums fail closed to the browser fallback
- OTA: `triggerInstall` now refuses any download handle that was not checksum-verified
- CI: release workflow gains a provenance check (tag must be on master) and a manual approval hold before signing/publishing
- CI: signed builds require a pinned `FLUTTER_COMMIT` env var and verify the cloned SDK SHA before use
- CI: releases publish a `SHA256SUMS-<tag>.txt` asset; `--dart-define` expansions are now quoted
- CI: release versionCode is floored above the sideload line so early build numbers can never under-rank sideloaded installs
- Client: delta-fetch watermark is clamped against the clock — a future-dated cached article falls back to a full fetch
- Client: Open-in-browser launches only http(s) links (no `intent://` or other app-handoff schemes)
- Client: source registry rejects non-http(s) feed URLs, mirroring the server's `handlePutSources` rule
- Swipe-to-save now enforces the same free cap as the save button (5-minute grace window), closing a self-entitlement bypass
- Play builds ignore an attacker-writable cloud `isPro` flag when unlocking entitlements

## [1.0.1] - 2026-03-23

### Fixed
- Removed unused freezed dependency (feed_state.dart) - app now builds cleanly
- Fixed missing GetIt import in article_detail_screen.dart
- Fixed type error in read_time_badge.dart (passing article.description instead of article)
- Fixed static access to RssFeedService.predefinedSources
- Fixed test infrastructure - GetIt service locator now handles re-registration properly

### Build
- All 110 tests now pass
- No blocking analysis errors

## [1.1.1] - 2025-02-10

### Fixed
- Added INTERNET permission - RSS feeds now load correctly
- Added ACCESS_NETWORK_STATE permission for connectivity detection

## [1.1.0] - 2025-02-10

### Added
- Auto-update feature using GitHub Actions and GitHub Releases
- Automatic check for new app versions on startup
- Update notification dialog with release notes
- Manual update check via settings menu
- Option to skip specific update versions

### Changed
- Improved update checking with hourly rate limiting

## [1.0.0] - 2026-03-03 (initial sideloaded build)

### Added
- Initial release of Curated Feeds app
- RSS feed reader with article list display
- Article detail view with web content parsing
- Swipeable card interface for browsing articles
- Card stack layout with expanded article cards
- Local storage for caching articles and sources
- RSS source management and filtering
- Automatic app updates via Shorebird
- Error handling with user-friendly dialogs
- Dependency injection with service locator
- Repository pattern implementation (ArticleRepository, FeedRepository)

### Fixed
- Article detail view improvements
- RSS source filtering
- Date formatting for local time compatibility

### Build
- Debug and release build configurations
- Shorebird build flavors configured
