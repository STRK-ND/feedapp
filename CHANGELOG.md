# Changelog

All notable changes to Curated Feeds will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Brand rollout (1.0.1) — new app logo on all surfaces
- Launcher icon rebuilt from `logo.png`: navy `#0E0814` adaptive background + extracted swirl/glyph foreground (66dp safe zone) + themed-icon layer; legacy + round rasters regenerated
- In-app splash and paywall now render the logo via the shared `AppLogo` widget (replaces the duplicated hand-painted glyph); Settings → About, onboarding, and login show the mark
- Native launch screen carries the logo on the matching theme ground; status-bar notifications use a white-silhouette icon
- **Fixed:** the notification icon name (`@mipmap/ic_launcher`) never resolved, which silently aborted push-token registration — now `ic_notification`, and splash bootstrap isolates notification init so it can't take down feed init
- Regenerate with `python3 tool/generate_brand_assets.py && dart run flutter_launcher_icons` (then sync `ic_launcher_round.xml`)

Remediation of the 2026-10-07/08 security & functional audit (`burp-audite.md`) — all four passes.
Findings are referenced by the audit's IDs.

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
