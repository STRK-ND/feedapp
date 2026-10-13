# Curated Feeds — Security & Functional Audit Report

| | |
|---|---|
| **Target** | Curated Feeds v1.0.0+26 (`com.curatedfeeds`) + Cloudflare Worker `curated-feeds-worker` |
| **Repository** | `STRK-ND/feedapp` @ `e4035ec` (branch `master`) |
| **Audit date** | 2026-10-07 (pass 1 — security) · 2026-10-07 (pass 2 — data layer) · 2026-10-07 (pass 3 — performance & battery) · 2026-10-07 (pass 4 — revenue & growth) |
| **Methodology** | Static source review · `flutter analyze` · full test suites · instrumented SQLite probes · live HTTP testing of the deployed worker via Burp Suite MCP · monetization-funnel review against the stated goal of earning revenue and growing users |
| **Status** | Report only. **No source files were modified.** Every "Implementation" section below is a *proposed* patch, not an applied one. |
| **Overall risk** | **LOW–MEDIUM** — 0 Critical, 0 High, **13 Medium** (M-1…M-3, F-1, F-2, P-1…P-4, R-1…R-4), **14 Low** (L-1…L-5, F-3…F-6, P-5…P-7, R-5, R-6), **10 Informational** (I-1…I-10) |

> **Scope note:** No Android SDK, `adb`, or emulator was available on the audit host. Device-runtime
> verification (logcat, on-device flows, Play Billing round-trip) could not be performed. Findings
> marked *source-level* were confirmed by reading code and tracing call paths; findings marked
> *live-verified* were confirmed with real HTTP requests against production. Everything else is
> explicitly labelled as unverified.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Application Architecture](#2-application-architecture)
3. [Finding Index](#3-finding-index)
4. [Medium Findings](#4-medium-findings)
5. [Low Findings](#5-low-findings)
6. [Informational](#6-informational)
7. [Verified Not Vulnerable](#7-verified-not-vulnerable)
8. [Code-to-HTTP Correlation](#8-code-to-http-correlation)
9. [Data-Layer Deep Debug (Pass 2)](#9-data-layer-deep-debug-pass-2)
10. [Test & Analysis Results](#10-test--analysis-results)
11. [Remediation Plan](#11-remediation-plan)
11.1 [Revenue-Priority Ranking](#111-revenue-priority-ranking)
12. [Performance & Battery Findings (Pass 3)](#12-performance--battery-findings-pass-3)
13. [Revenue & Growth Findings (Pass 4)](#13-revenue--growth-findings-pass-4)
14. [Files Touched by This Audit](#14-files-touched-by-this-audit)

---

## 1. Executive Summary

**Architecture.** A Flutter 3.47.6 / Dart 3.13.5 Android-only reader app backed by a Cloudflare
Worker (Workers KV RSS aggregator), Firebase (Auth, Firestore, FCM, Crashlytics, Analytics), and
optional PostHog/Sentry. Local-first: SQLite is the source of truth for the UI, Firestore mirrors
per-user triage state.

**What the codebase gets right.** This project has clearly been through prior security passes, and
those fixes hold up under live testing. The worker authorization fails closed when secrets are
unset. Admin authority is properly separated from the app-embedded secret. The OTA install path
verifies SHA-256 before handing bytes to the system installer and refuses unverified handles. The
CI release workflow enforces a master-lineage provenance gate plus a manual approval hold before
signing material is decoded. Firestore rules scope every document to `request.auth.uid`. No
secrets were ever committed — verified across all refs.

**Where the remaining risk sits.** Two clusters.

**Business logic, not plumbing.** `is_pro` travels inside the synced settings snapshot, and
Firestore rules let a user write their own documents. A signed-in user can therefore set the Pro
entitlement on their own account without purchasing anything (M-1), and a second, not-yet-synced
device can revoke a Pro purchase made elsewhere (F-2). This defeats the Play-store-specific
entitlement hardening shipped in 1.0.0, because that guard only covers one of the two code paths
that can set the flag. One root cause, two directions — grant for free, or take away a purchase.

**Data integrity.** The feed cache and the Saved list are two SQLite tables holding overlapping
state, and only one is treated as authoritative when the Saved list is rebuilt. A saved article
that falls outside the 1000-row cache cap is silently deleted on the next cloud sync (F-1). This is
the only finding in the report that destroys user data.

**Cost and abuse.** Two worker findings follow from a deliberate design choice — the app-level
shared secret is embedded in the distributed APK. That is documented and accepted in the source, but
it means the `/subscribe` guard is effectively public, which turns a per-token rate-limit key into a
real write-amplification vector (M-2). Separately, cloud sync reads the whole article collection on
every cold start (F-4) and pushes two identical documents on every feed refresh (F-5).

**Wasted work.** A quarter of every feed response is duplicated bytes the client already has (P-1),
the worker re-sorts its entire cache to serve a 50-item page (P-3), and the client spends a
rate-limited third-party request on every cold start for a check that changes once per release (P-2).

**Pass 2 — data layer.** A second pass instrumented the SQLite layer directly with throwaway probe
tests and traced the cloud-sync reconciliation paths. This surfaced **six functional defects the
security pass had missed** (F-1 … F-6). Two are Medium and were previously invisible:

- **F-1 — data loss.** `saveArticles` caps the feed cache at 1000 rows, but `_reconcileArticles`
  rebuilds the Saved tab from the feed table alone. A saved article older than the cap is silently
  deleted from the user's saved list on the next cloud sync. Confirmed by probe.
- **F-2 — revenue loss.** `_pushSettings` writes `isPro` from the local preference on *every*
  settings push. On a second device that has not yet synced, a routine preference change **revokes
  Pro** that was purchased elsewhere. Same root cause as M-1, opposite direction: the same
  `is_pro` transport both grants Pro for free and takes it away.

The remaining four (F-3 … F-6) are Low: an unwired tombstone pruner, an unbounded Firestore read,
a per-refresh sync write, and a dead Settings option.

Notably the M-1 fix (removing `is_pro` from the synced-keys list) **resolves F-2 as well** — one
change, two defects closed.

**Pass 3 — performance and battery.** Burp Suite MCP was used to probe response shapes, payload
composition, and latency against the live worker. Seven more findings (P-1 … P-7), three of them
Medium:

- **P-1** — `fullContent` is a byte-for-byte copy of `description` in **100 of 100** measured
  articles. **26% of every feed payload is duplicated data.**
- **P-2** — the hourly update-check throttle is dead: the automatic caller passes `forceCheck: true`,
  so every cold start spends one of GitHub's **60 unauthenticated requests/hour**, bucketed per
  source IP. Shared under CGNAT/NAT, and silent when exhausted.
- **P-3** — `/articles` filters and sorts the **entire** cached array before slicing. Measured:
  `pageSize=1` costs 446 ms against `pageSize=50`'s 493 ms, so requesting fewer items does not make
  the request cheaper.
- **P-4** — `matchingTokens` issues one KV `get` per subscriber on every cron cycle. Compounds M-2.
- **P-7** lists the client-side hot paths but is explicitly **unmeasured** — no `adb` or emulator on
  the audit host. Numbered rather than omitted, since leaving it out would imply it had been checked.

One hypothesis was **disproved** and recorded so it is not re-investigated: the worker *does*
compress responses. Burp's `content-encoding: ABSENT` is Burp decoding transparently — `curl`
confirms gzip works at **4.4×** (127,191 → 28,792 bytes).

**Pass 4 — revenue and growth.** Re-audited against a different objective: **earn revenue and grow
users.** Six more findings (R-1 … R-6), four of them Medium, and one that outranks almost everything
above it:

- **R-1 — the upsell never fires.** There is exactly **one** `PaywallScreen()` construction in the
  codebase (`settings_screen.dart:534`), reached only from Settings. Both cap-hit sites
  (`feed_screen.dart:443`, `:508`) show a SnackBar reading *"Free limit of 5 saved articles reached —
  Go Pro for unlimited saves"* and return. The one moment a user has demonstrated intent to pay is
  the one moment the app does not offer the purchase. **This is the highest-value fix in the report:**
  two lines, no regression risk, and no other finding recovers revenue already being dropped.
- **R-2 — no account deletion flow.** Exhaustive search: `deleteAccount`, `deleteUser`,
  `accountDeletion`, `Delete account` → **0 hits**. Play requires an in-app deletion path for any app
  that creates accounts. `docs/play-store-release.md:47` lists it as a pre-submission item; it is not
  implemented. Blocks the first upload and every update after.
- **R-3 — zero funnel analytics.** `AnalyticsService` has 16 events, none paywall or purchase
  related; `paywall_screen.dart` fires none at all. You cannot measure whether R-1 worked.
- **R-4 — no in-app review prompt.** `in_app_review` is not a dependency. Ratings are a ranking
  input and there is no path from a satisfied user to one.
- **R-5 / R-6** — 65.6 MB APK across 3 ABIs with no splits; no `fastlane` or store metadata in repo.

**Why passes 1–3 missed all of this, stated plainly: an audit optimised for security does not find
revenue leaks.** R-1 in particular is not a bug by any conventional measure — a SnackBar explaining
a limit is *correct*. It only becomes a defect when the goal is conversion. See
[§13.0](#130-why-these-were-absent-from-passes-13).

Because the two objectives disagree, [§11.1](#111-revenue-priority-ranking) re-ranks all 27
numbered findings by money rather than severity. Two move: **M-1/F-2 up** (they attack the only
monetised surface the app has), **M-2/P-4 down** (technically the most interesting findings in the
report, but they cost nothing at current subscriber scale).

**Baseline health.** `flutter analyze` reports **0 issues**. `dart format` reports **0 files
changed**. 251 Flutter tests pass, though one is flaky (~1 in 10 full parallel runs). All 32 worker
tests pass.

| **What to do first depends on your objective.** Under *security* hygiene, fix **F-1** first — the
only finding that destroys user data, at 12 lines. Under *revenue*, fix **R-1** first, then **R-2**,
then M-1 + F-2. The two orderings disagree and the disagreement is itself a finding; both are in
[§11](#11-remediation-plan) and [§11.1](#111-revenue-priority-ranking).

**Nothing here is a security emergency.** No finding permits unauthorized data access, code
execution, or authentication bypass. The Medium items affect revenue (R-1, M-1, F-2), distribution
(R-2), measurability (R-3), growth (R-4), reliability (M-3 — push registration is silently dead for
builds using the stale secret), and cost (M-2).

---

## 2. Application Architecture

### 2.1 Stack

| Layer | Detail |
|---|---|
| Framework | Flutter 3.47.6 stable · Dart 3.13.5 · `environment.sdk: ^3.10.8` |
| Frontend | Flutter widgets · `provider` (state) + `get_it` 9.x (DI) · Material 3 · l10n (en, hi) |
| Backend | Cloudflare Worker `curated-feeds-worker` (`workers/feed-worker.js`, 929 lines) |
| Datastores | sqflite `curated_feeds.db` (v2) · Cloudflare KV `ARTICLES_KV` · Firestore |
| ORM | None — hand-written parameterized SQL (`lib/services/feed_database.dart`) |
| Auth | Firebase Auth — Google one-tap + email/password. No custom sessions or JWTs |
| Authorization | Worker: `x-api-secret` (SHA-256 + constant-time compare), separate `ADMIN_SECRET`. Firestore: `firestore.rules` |
| API | 7 REST endpoints, no GraphQL |
| Uploads | None |
| Downloads | APK OTA via `open_filex`, OPML export via share sheet, images via cache manager |
| Payments | `in_app_purchase` · single non-consumable `cf_pro_lifetime` · **no server-side receipt validation** |
| Background jobs | WorkManager periodic sync (15-min floor) + worker cron `*/5 * * * *` |
| Webhooks | None inbound. Outbound FCM HTTP v1 via service-account JWT |
| Secrets | `--dart-define` only: `WORKER_API_SECRET`, `SENTRY_DSN`, `POSTHOG_API_KEY`, `UPDATES_REPO` |
| Deployment | CircleCI → GitHub Releases (sideload) + Play Store AAB (manual). Worker via `wrangler` |

### 2.2 Worker Endpoints

| Method | Path | Auth | Rate limit | Purpose |
|---|---|---|---|---|
| GET | `/health` | none | none | Liveness |
| GET | `/articles` | none (public by design) | 120 / 60s / IP | Paginated merged feed |
| GET | `/sources` | none (public by design) | 60 / 60s / IP | Canonical source registry |
| PUT | `/sources` | `ADMIN_SECRET` | none | Override global source list |
| GET | `/articles/refresh` | `API_SECRET` | 5 / 60s / IP | Force cache refresh |
| POST | `/subscribe` | `API_SECRET` | 10 / 60s / **(token+IP)** | Register FCM token |
| DELETE | `/subscribe` | `API_SECRET` | 10 / 60s / **(token+IP)** | Remove FCM token |

### 2.3 Data Layer (added in pass 2)

| Component | Detail |
|---|---|
| Local store | sqflite `curated_feeds.db`, schema **version 2** |
| Tables | `articles` (feed cache: `id`, `pub_date`, `payload` JSON, `updated_at`) · `saved_articles` (adds `position`) |
| Payload format | JSON-encoded `Article` maps — model layer and worker contract unchanged by the move to SQLite |
| Row clock | `updated_at` epoch-ms, the LWW merge clock. Added in v1→v2 migration |
| Cache cap | `AppConfig.maxCachedArticles = 1000`, enforced only inside `saveArticles` |
| Display cap | `max_articles` pref (100/250/500/1000/2000), applied on read in `feed_screen` |
| Merge | `mergeArticles` in `sync_merge.dart` — pure, no Firebase imports, unit-tested |
| Tombstones | `users/{uid}/sync_state/main.deletions` — `{articleId: ts}` map |
| Cloud mirror | `users/{uid}/articles/{articleId}`, batched 400 writes, **read back with no limit** |

**Schema notes.** The v1→v2 migration (`FeedDatabase.migrate`) adds `updated_at` to both tables and
defaults legacy rows to `0` so remote state wins on first sync. Verified working by probe: a
hand-built v1 database migrates, the column is added, the row survives, and `updated_at` reads `0`.

**Known sharp edge:** `FeedDatabase._open` always prefixes `path` with `getDatabasesPath()`, so an
absolute path is silently re-rooted under the platform databases directory. Fine for the app; it
misled the first migration probe until the harness was corrected.

### 2.4 Highest-Risk Attack Surfaces

1. **The Pro entitlement trust boundary** — a client-writable flag gates paid features.
2. **Worker routes guarded by an APK-embedded secret** — the secret is public by design.
3. **The OTA install path** — remote APK → system installer. (Audited; found sound.)
4. **Firestore sync reconciliation** — client-authoritative conflict resolution.
5. **The feed-cache cap vs. the Saved list** — two tables, one rebuild path (F-1).

---

## 3. Finding Index

| ID | Severity | Finding | Confidence |
|---|---|---|---|
| **M-1** | Medium | Pro entitlement self-grant via cloud settings document | source-level |
| **M-2** | Medium | Per-token rate-limit key allows unbounded subscription writes | source-level |
| **M-3** | Medium | Local `WORKER_API_SECRET` does not match production | live-verified |
| **F-1** | Medium | **Saved articles silently deleted by the cache cap during cloud sync** | **probe-verified** |
| **F-2** | Medium | Cloud sync silently revokes Pro purchased on another device | source-level |
| **L-1** | Low | Rate limiter is a non-atomic KV read-modify-write | live-verified |
| **L-2** | Low | Missing security headers on worker responses | live-verified |
| **L-3** | Low | No length cap on the `q` search parameter | live-verified |
| **L-4** | Low | Release build silently falls back to debug signing | source-level |
| **L-5** | Low | Flaky test: `paywall_screen_test.dart` | live-verified |
| **F-3** | Low | Tombstone map grows without bound — `pruneDeletions` is dead code | source-level |
| **F-4** | Low | Cloud sync reads the entire article collection on every launch | source-level |
| **F-5** | Low | Edition-counter bump writes to the cloud on every refresh | source-level |
| **F-6** | Low | "Max articles: 2000" is unreachable — cap is 1000 | source-level |
| **P-1** | Medium | `fullContent` duplicates `description` — 26% of every payload | **live-measured** |
| **P-2** | Medium | Hourly update-check throttle is dead — GitHub quota spent per cold start | **live-measured** |
| **P-3** | Medium | `/articles` latency scales with total cached articles, not page size | **live-measured** |
| **P-4** | Medium | `matchingTokens` is O(subscribers) KV GETs per cron cycle | source-level |
| **P-5** | Low | `announceNewArticles` does serial GET+PUT per article | source-level |
| **P-6** | Low | No `Cache-Control` / `ETag` / `Last-Modified` on any response | **live-measured** |
| **P-7** | Low | Client hot paths with plausible battery cost — **unquantified** | unmeasured |
| **R-1** | Medium | **Cap-hit shows a SnackBar and never routes to the paywall** | source-level |
| **R-2** | Medium | No account deletion flow — Play submission blocker | source-level |
| **R-3** | Medium | Zero paywall/purchase analytics — funnel unmeasurable | source-level |
| **R-4** | Medium | No in-app review prompt | source-level |
| **R-5** | Low | 65.6 MB APK / 66 MB AAB across 3 ABIs, no splits | source-level |
| **R-6** | Low | No fastlane, store metadata, or listing copy in repo | source-level |
| **I-1…I-10** | Info | Miscellaneous — see [§6](#6-informational) | mixed |

> **M-1 and F-2 share one root cause.** `is_pro` rides in the synced-preferences snapshot. M-1 is
> the attacker-grants direction; F-2 is the sync-revokes direction. The single-line fix for M-1
> closes both.

> **P-4 compounds M-2.** M-2 lets an attacker inflate the `sub:` key-space at will; P-4 is what
> makes that inflation expensive. Fixing M-2 removes the attack; P-4 removes the scaling cliff. Both
> are worth doing, and neither substitutes for the other.

> **P-7 is deliberately unmeasured.** No `adb`, emulator, or Android SDK on the audit host, so
> frame timing, jank, isolate churn, and mAh drain could not be measured. It is numbered rather than
> omitted — an audit that left it out would imply it had been checked and found clean, which would
> be false.

> **R-1 is not a security finding and was invisible to passes 1–3.** A SnackBar on a cap-hit is
> correct behaviour. It becomes a defect only under a revenue objective. See
> [§13.0](#130-why-these-were-absent-from-passes-13) — and note that under revenue priority,
> **M-1/F-2 move up** (they attack the only monetised surface) while **M-2/P-4 move down** (cost, not
> revenue, at current scale). See [§11.1](#111-revenue-priority-ranking).

---

## 4. Medium Findings

---

### [MEDIUM] M-1 · Pro Entitlement Self-Grant via Cloud Settings Document

| | |
|---|---|
| **Endpoint** | Firestore `users/{uid}/settings/main` |
| **HTTP Method** | `set` / `PATCH` via the Firestore SDK |
| **Affected Component** | Entitlement gate — unlocks unlimited saved articles and the sepia / e-ink reader themes |
| **Confidence** | source-level (no production data modified) |

**Affected source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/services/settings_service.dart` | 382 | `'is_pro'` listed in `_syncedBoolKeys` |
| `lib/services/settings_service.dart` | 413–427 | `restoreFromSync` writes any `bool` in that list straight to `SharedPreferences` |
| `lib/services/cloud_sync_service.dart` | 151–157 | `_reconcileSettings` calls `restoreFromSync(values)` when the cloud clock wins |
| `lib/services/cloud_sync_service.dart` | 278–297 | `_restoreProFlag` — the Play-build guard |
| `firestore.rules` | 9–14 | permits any field on the user's own documents |

**Description**

Release 1.0.0 added a Play-build entitlement guard: on Play, a cloud `isPro` flag alone must not
unlock Pro without a locally verified purchase. That guard lives in `_restoreProFlag`, which reads
exactly one field:

```dart
// lib/services/cloud_sync_service.dart:278-297
Future<void> _restoreProFlag(String uid) async {
  final data = (await _userDoc(uid).get()).data();
  final cloudPro = data?['isPro'] == true;
  if (!cloudPro) return;
  if (AppConfig.isPlayStoreBuild && !(await _settings.getIsPro())) {
    debugPrint('[CloudSync] Cloud Pro flag ignored on Play build ...');
    return;                                     // <-- returns EARLY, never clears
  }
  if (!(await _settings.getIsPro())) {
    await _settings.setIsPro(true);
  }
}
```

But Pro is *also* carried a second way: as the plain synced boolean `is_pro` inside the settings
snapshot document. `_reconcileSettings` restores that snapshot **first**, with no entitlement check
of any kind:

```dart
// lib/services/cloud_sync_service.dart:151-157
if (cloudTs > localTs) {
  final values = (data?['values'] as Map?)?.cast<String, Object?>() ?? const {};
  await _settings.restoreFromSync(values);     // <-- sets is_pro directly, unverified
  await _settings.setSettingsSyncTs(cloudTs);
  await _restoreProFlag(uid);                  // <-- runs AFTER; only ever adds
  if (!_settingsRestored.isClosed) _settingsRestored.add(null);
}
```

`restoreFromSync` performs no verification:

```dart
// lib/services/settings_service.dart:419-422
for (final k in _syncedBoolKeys) {
  final v = values[k];
  if (v is bool) await _prefs.setBool(k, v);   // no entitlement gate
}
```

So the ordering means `_restoreProFlag` is reached with `getIsPro()` already `true`. It is purely
*additive* — it never clears a stale `true`, and its Play-build early-return does not undo the
value `restoreFromSync` just wrote.

Meanwhile Firestore rules grant the user full write access to their own documents:

```
// firestore.rules:9-14
match /users/{uid} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
  match /{document=**} {
    allow read, write: if request.auth != null && request.auth.uid == uid;
  }
}
```

The user therefore owns the input to the trust decision.

**Reproduction** *(local test only; no production data touched)*

1. Sign in to any account on a Play or direct build.
2. Using that account's own credentials, write:
   `users/{uid}/settings/main = { updatedAt: <future epoch ms>, values: { is_pro: true } }`
3. Relaunch the app. `_reconcileSettings` observes `cloudTs > localTs` and calls `restoreFromSync`.
4. `SharedPreferences['is_pro']` becomes `true`. Pro features unlock — on the **Play build, with no
   Play purchase**.

**Note on the `updatedAt` value.** The attacker must set it *ahead* of the local
`sync_settings_updated_at` clock, because `_reconcileSettings:151` compares `cloudTs > localTs` and
only restores when the cloud is strictly newer. Using wall-clock-now is not sufficient on a device
that has synced recently — a future timestamp is required. The local clock is a plain
`SharedPreferences` int, so its magnitude is known to the account owner.

**Evidence** (source trace)

- `_syncedBoolKeys` contains `'is_pro'` — `settings_service.dart:382`
- `restoreFromSync` has no entitlement branch — `settings_service.dart:413-427`
- `_restoreProFlag` runs after `restoreFromSync` and short-circuits on `cloudPro == false` —
  `cloud_sync_service.dart:151-157, 285-286`
- Rules permit the write — `firestore.rules:9-14`
- Existing coverage gap: `grep 'restoreFromSync|snapshotForSync' test/` → **no matches**

**Root cause**

The entitlement check was placed on one transport path instead of at the single point where the
flag becomes authoritative — the write into local storage. Two independent paths can set the same
value; only one is guarded.

**Impact**

Any user unlocks paid features for free on **both** distribution channels. On Play this fully
bypasses the verified-purchase requirement, which has direct revenue impact and touches Play Store
policy compliance (paid features must have a functioning purchase path). No privacy or data-access
impact — the blast radius is the paywall.

**Self-limiting factor worth stating.** `_ensureUserDoc` (`cloud_sync_service.dart:125-137`) only
writes the user document `if (!exists)`, and an existing doc's `isPro` field is not re-initialised —
so the forged `settings/main` value persists across syncs rather than being corrected. The forged
`is_pro` also round-trips: once `restoreFromSync` writes it locally, `snapshotForSync` includes it
again (`settings_service.dart:393-409`), so the value re-propagates to any other device the user
signs into. **One forgery becomes account-wide**, which raises the stakes slightly above a
single-device unlock.

**Implementation**

Remove the entitlement from the synced-preferences transport, and gate the single authoritative
write.

```dart
// lib/services/settings_service.dart — step 1: stop transporting it
static const List<String> _syncedBoolKeys = [
  'notifications_enabled',
  'new_article_notifs',
  'in_app_notifications_enabled',
  'auto_refresh',
  'show_images',
  'data_saver_mode',
  // 'is_pro',   <-- REMOVED: entitlement must never travel as a synced pref.
                 //     It is applied only via CloudSyncService._restoreProFlag,
                 //     which holds the verified-purchase rule for Play builds.
  'mono_datelines',
  'widen_measure',
];
```

```dart
// lib/services/cloud_sync_service.dart — step 2: make the guard authoritative,
// not additive. A stale local `true` must not survive.
Future<void> _restoreProFlag(String uid) async {
  final data = (await _userDoc(uid).get()).data();
  final cloudPro = data?['isPro'] == true;
  if (!cloudPro) return;
  if (AppConfig.isPlayStoreBuild && !(await _settings.getIsPro())) {
    debugPrint('[CloudSync] Cloud Pro flag ignored on Play build without a '
        'verified local purchase.');
    return;
  }
  if (!(await _settings.getIsPro())) {
    await _settings.setIsPro(true);
  }
}
```

Step 2 is defensive only — with step 1 in place, `restoreFromSync` can no longer set the flag, so
the guard becomes the only writer. Keeping the explicit comment documents *why* the ordering
matters if someone later re-adds `is_pro` to the synced list.

Optionally harden `restoreFromSync` itself against future regressions:

```dart
Future<void> restoreFromSync(Map<String, Object?> values) async {
  await init();
  // Defence in depth: entitlement is never accepted from a synced snapshot.
  final safe = Map<String, Object?>.from(values)..remove('is_pro');
  for (final k in _syncedStringKeys) { /* ...unchanged... */ }
  for (final k in _syncedBoolKeys) { /* ...unchanged... */ }
  for (final k in _syncedListKeys) { /* ...unchanged... */ }
}
```

**Verification**

Add to `test/unit/services/` (new file, e.g. `entitlement_test.dart`):

1. `restoreFromSync({'is_pro': true})` → `getIsPro()` remains `false`.
2. `snapshotForSync()` output does not contain the key `is_pro`.
3. Play build (`isPlayStoreBuild` forced true in a `--dart-define` test build) + `_restoreProFlag`
   with `isPro: true` and no local purchase → Pro stays off.
4. Regression guard: reinstall-on-new-device still restores Pro through
   `setPro` → `users/{uid}.isPro` → `_restoreProFlag`.

Then `flutter analyze && flutter test`.

**Regression risk**

Pro will no longer follow a user across reinstall via the *settings* document. It already has a
dedicated path — `CloudSyncService.setPro` (`cloud_sync_service.dart:384-393`) writes
`users/{uid}.isPro`, and `_restoreProFlag` reads it. Verify test 4 above before shipping; if it
fails, the entitlement needs its own small doc rather than a return to the synced list.

---

### [MEDIUM] M-2 · Per-Token Rate-Limit Key Allows Unbounded Subscription Writes

| | |
|---|---|
| **Endpoint** | `POST /subscribe` |
| **HTTP Method** | POST |
| **Affected Component** | `consumeRate` call site |
| **Confidence** | source-level (logic confirmed by reading; not executed against production) |

**Source location** — `workers/feed-worker.js:305-316`

```js
const subIp = request.headers.get('CF-Connecting-IP') ?? 'local';
if (!(await consumeRate(env, 'sub:' + token + subIp, 10, 60)) {
  return json({ error: 'rate_limited' }, 429);
}

await env.ARTICLES_KV.put(`sub:${token}`, JSON.stringify({
  token, topic: body.topic || 'new-articles', preferences: prefs, createdAt: Date.now(),
}), { expirationTtl: 90 * 24 * 3600 });
```

**Description**

The rate-limit key is built from the caller-supplied `token`, so the limit is scoped **per token**
rather than per caller. Ten requests per minute each bearing a distinct token is, by construction,
unlimited writes.

This matters more than a typical keying bug because the worker header states the design intent
plainly (`feed-worker.js:21-24`):

> `API_SECRET` — shared app secret. The distributed APK embeds it … so treat it as public
> knowledge, not a security boundary.

And it does embed it: `lib/utils/constants.dart:79` compiles it via `String.fromEnvironment`, and
`.circleci/config.yml:140-146` passes `--dart-define="WORKER_API_SECRET=$WORKER_API_SECRET"` into
every release build. Anyone who unpacks the APK obtains it. The `/subscribe` gate is therefore
reachable by the general public.

Each accepted write creates a `sub:<token>` KV row with a **90-day TTL**. On every refresh that
finds new articles, `matchingTokens` (`feed-worker.js:713-728`) lists *all* `sub:` keys and issues
one KV `get` per row:

```js
async function matchingTokens(env, categories) {
  const tokens = [];
  let cursor;
  do {
    const page = await env.ARTICLES_KV.list({ prefix: 'sub:', cursor });
    for (const { name } of page.keys) {
      const row = await env.ARTICLES_KV.get(name, 'json');
      if (!row || typeof row.token !== 'string') continue;
      if (!rowMatchesCategories(row, catSet)) continue;
      tokens.push(row.token);
    }
    cursor = page.cursor;
  } while (cursor);
  return tokens;
}
```

**Reproduction** *(not executed — see note)*

1. Extract `API_SECRET` from any release APK.
2. `POST /subscribe` 10+ times, each with a distinct token of ≥10 characters.
3. All return `200 {"ok":true}`. An 11th request repeating the *same* token returns `429`.

*Note:* I did **not** run this against production. The only secret available on the audit host was
already invalid (see M-3), so the 401 responses proved nothing about the rate-limit behaviour. The
finding is confirmed by reading the key construction, not by request.

**Evidence**

- Key includes caller input — `feed-worker.js:306`
- Secret is compiled into the APK — `lib/utils/constants.dart:79`, `.circleci/config.yml:140-146`
- Design intent documented — `feed-worker.js:21-24`
- Amplification path — `feed-worker.js:713-728`
- Existing test covers token *shape* only, not the limit key — `workers/test/feed-worker.test.js:541`

**Root cause**

A caller-controlled value was included in the rate-limit key, scoping the limit to the wrong
subject. The rate limiter is meant to bound the caller; instead it bounds one of the caller's
parameters.

**Impact**

KV write amplification plus a growing per-refresh read cost (`matchingTokens` is O(subscribers)
with a `get` each, executed inside the 5-minute cron). At scale this degrades refresh latency and
increases Cloudflare billing. `announceNewArticles` then attempts an FCM multicast per refresh.
No data is exposed; no authentication is bypassed.

**Implementation**

```js
// workers/feed-worker.js:305-316
const subIp = request.headers.get('CF-Connecting-IP') ?? 'local';
// Key on the CALLER, not the token. Previously keyed `sub:${token}${subIp}`,
// which meant the 10/min cap applied per token and a caller could mint
// unlimited rows by varying it — and the secret gating this route ships in
// the APK, so the route is effectively public.
if (!(await consumeRate(env, 'sub:' + subIp, 10, 60))) {
  return json({ error: 'rate_limited' }, 429);
}
```

Apply the identical change to `handleUnsubscribe` (`feed-worker.js:335-338`), which has the same
keying pattern.

Optionally add a global subscription ceiling so a distributed attacker cannot inflate the list
regardless of source IPs:

```js
const subTotal = await env.ARTICLES_KV.get('sub:__count', 'json');
if ((subTotal?.n ?? 0) >= MAX_SUBSCRIPTIONS) {
  return json({ error: 'capacity' }, 503);
}
```

**Verification**

Extend `workers/test/feed-worker.test.js` (next to the existing case at line 541):

```js
test('subscribe rate limit is per caller, not per token', async () => {
  const env = workerEnv();
  // 10 distinct tokens from one IP -> the 11th call is rejected regardless of token.
  for (let i = 0; i < 10; i++) {
    const res = await worker.fetch(workerRequest('/subscribe', {
      method: 'POST', body: { token: `tok-${i}-aaaaaaaaaa` }, secret: 'test-secret',
    }), env, noopCtx);
    assert.equal(res.status, 200, `call ${i} should pass`);
  }
  const blocked = await worker.fetch(workerRequest('/subscribe', {
    method: 'POST', body: { token: 'a-brand-new-token-xx' }, secret: 'test-secret',
  }), env, noopCtx);
  assert.equal(blocked.status, 429, '11th distinct token must still be rate limited');
});
```

Then `node --test` in `workers/`.

**Regression risk**

Users toggling push rapidly across several devices behind one NAT share a single 10/min bucket.
That pattern is rare, and the limit is generous for it — but if push registration failures appear
in the field, raise the limit rather than re-keying per token.

---

### [MEDIUM] M-3 · Local `WORKER_API_SECRET` Does Not Match Production

| | |
|---|---|
| **Endpoint** | `POST /subscribe`, `GET /articles/refresh` |
| **HTTP Method** | POST, GET |
| **Affected Component** | Push-notification registration |
| **Confidence** | **live-verified** against production |
| **Classification** | Operational / configuration, not a code defect |

**Evidence.** Both request shapes return an identical `401 {"error":"unauthorized"}`, which is why
the drift is invisible without checking the worker's structured logs:

| Request | Response |
|---|---|
| `x-api-secret: <env.txt value>` | `401 {"error":"unauthorized"}` |
| `x-api-secret: <wrong value>` | `401 {"error":"unauthorized"}` |
| no header | `401 {"error":"unauthorized"}` |
| `x-api-secret: ` (empty) | `401 {"error":"unauthorized"}` |

**Source locations**

- `env.txt` line 74 — `WORKER_API_SECRET` (30 chars, **value redacted**)
- `.circleci/config.yml:140-146` — injects it into every release build
- `lib/services/notification_service.dart:167-171` — swallows the failure

**Description**

The `WORKER_API_SECRET` value stored in `env.txt` is rejected by the deployed worker. Every
authenticated request using it returns `401 {"error":"unauthorized"}`.

The worker's own error logging distinguishes the two failure modes (`feed-worker.js:151-153`):

```js
if (!env.API_SECRET) {
  console.error('api_secret_not_configured');
  return false;
}
```

A configured-but-mismatched secret logs nothing, so the 401 confirms the secret *is* set and
simply does not match.

Any release build compiled with this stale value ships an app whose push registration fails
silently:

```dart
// lib/services/notification_service.dart:167-171
unawaited(
  NotificationService.enablePushNotifications().catchError((Object e) {
    debugPrint('[Notification] Failed to register token with worker: $e');
  }),
);
```

`enablePushNotifications` throws `StateError('Push subscription failed: HTTP 401')`, which is
caught and logged. Users receive no "new articles" push and no error surfaces anywhere.

**Reproduction**

```bash
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "x-api-secret: $(<env.txt value)" \
  -H 'Content-Type: application/json' \
  -X POST --data '{"token":"audit-probe-token-0001"}' \
  https://curated-feeds-worker.raj15400881.workers.dev/subscribe
# → 401
```

A control request with no header also returns `401`, which is why the two conditions are easy to
confuse without checking the worker's logs.

**Hygiene note:** a probe token was used and immediately deleted via `DELETE /subscribe`; the probe
artifact was written to a `0600` temp file outside the repo and removed. No production state was
left behind. The secret value is redacted everywhere in this report.

**Root cause**

Secret drift between the local handoff file and the deployed worker's `API_SECRET` — either
rotation, or the file predates the current deployment. Because `API_SECRET` is stored via
`wrangler secret put`, it is invisible to CI config review: **the drift is undetectable without a
live probe like this one.**

**Impact**

Silent loss of push notifications for any build using the stale value. No security exposure — a
wrong secret fails closed, which is the correct behaviour and is itself evidence the M-series
fail-closed fix works.

**Implementation**

Operational, not code:

1. `wrangler secret put API_SECRET` — set the worker's secret to the intended value (or read the
   current one and update `env.txt`).
2. Re-sync the CircleCI project variable `WORKER_API_SECRET`.
3. Confirm with the probe above; expect `200 {"ok":true}`.

Recommended code follow-up so this cannot fail silently again:

```dart
// lib/services/notification_service.dart — surface a 401 distinctly.
if (response.statusCode == 401) {
  unawaited(ErrorHandler.logError(
    'Worker rejected push registration (401) — WORKER_API_SECRET is stale '
    'or unset. Push notifications are disabled.',
    severity: ErrorSeverity.high,
  ));
  throw StateError('Push subscription rejected: worker secret mismatch');
}
if (response.statusCode != 200) {
  throw StateError('Push subscription failed: HTTP ${response.statusCode}');
}
```

Because `logError` forwards to Sentry in release builds (`error_handler.dart:53-60`), this turns a
silent user-facing outage into an alert.

**Verification**

Re-run the probe. App secret → `200`; no header → `401`.

**Regression risk**

None. Worth adding the startup health check above so future drift is visible within one release
cycle rather than at the next audit.

---

### [MEDIUM] F-1 · Saved Articles Silently Deleted by the Cache Cap During Cloud Sync

| | |
|---|---|
| **Endpoint** | Firestore `users/{uid}/articles` (pull side) |
| **Affected Component** | `FeedDatabase.saveArticles` × `CloudSyncService._reconcileArticles` |
| **Confidence** | **probe-verified** — instrumented SQLite test, reproduced then deleted |
| **Classification** | **Data loss.** The only finding in this report that destroys user data. |

**Affected source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/services/feed_database.dart` | 120–158 | `saveArticles` caps to `maxCachedArticles` and **deletes** the overflow from `articles` |
| `lib/utils/constants.dart` | 111 | `maxCachedArticles = 1000` |
| `lib/services/cloud_sync_service.dart` | 237–242 | rebuilds the Saved tab from `loadArticles()` **only** |
| `lib/services/feed_database.dart` | 277–295 | `saveSavedArticles` deletes the whole `saved_articles` table, then reinserts |

**Description**

The feed cache and the saved list are two tables holding overlapping state. `saveArticles`
enforces the 1000-row cap by keeping the newest 1000 and **deleting everything else** from
`articles`:

```dart
// lib/services/feed_database.dart:145-157
await db.transaction((txn) async {
  await txn.delete(_articlesTable);        // full wipe
  final batch = txn.batch();
  for (final a in kept) {                  // kept = newest 1000 by pubDate
    batch.insert(_articlesTable, {
      'id': a.id, 'pub_date': ..., 'payload': encodeArticle(a),
      'updated_at': existing[a.id] ?? 0,    // clocks captured BEFORE the wipe
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
});
```

A saved article that falls outside the newest 1000 is removed from `articles` — but its
`saved_articles` row survives, because `saveArticles` never touches that table.

The store is now inconsistent: the article exists in `saved_articles` and **not** in `articles`.
On the next cloud sync, `_reconcileArticles` rebuilds the Saved tab from the feed table alone:

```dart
// lib/services/cloud_sync_service.dart:237-242
if (merge.toUpsert.isNotEmpty || merge.toUnsave.isNotEmpty) {
  final merged = await _storage.loadArticles();          // articles table ONLY
  final savedRows = merged.where((a) => a.isSaved).toList()
    ..sort((a, b) => b.pubDate.compareTo(a.pubDate));
  await _storage.saveSavedArticles(savedRows);           // wipes + reinserts
}
```

`saveSavedArticles` opens with `delete(_savedTable)` (`feed_database.dart:280`). Any
`saved_articles` row without a matching `articles` row is therefore **destroyed** — no prompt, no
undo, no error.

**Reproduction** *(instrumented probe, since removed)*

```dart
// 1001 articles: one 900-day-old SAVED article + 1000 fresh ones.
await db.saveArticles([old, ...fresh]);
await db.upsertSavedArticle(old);
final all   = await db.loadArticles();
final saved = await db.loadSavedArticles();
final ts    = await db.loadArticleTimestamps();
```

**Evidence** (verbatim probe output)

```
PROBE A: articles rows=1000
PROBE A: saved rows=1
PROBE A: OLD-SAVED present in articles table? false      <-- wiped by the cap
PROBE A: OLD-SAVED present in saved_articles? true       <-- orphaned
PROBE A: OLD-SAVED has a clock entry? false              <-- clock lost with it
PROBE D: articles=1000 clockHasOld=false clockValue=null
```

The missing clock is a second-order problem: `loadArticleTimestamps` no longer has the id, so
`mergeArticles` treats its local clock as `0` (`sync_merge.dart:56`). Any remote doc with
`updatedAt > 0` then wins and re-upserts a row whose triage state is stale — write amplification
layered on top of the data loss.

**Root cause**

Two tables hold overlapping state, but only one is treated as authoritative for the rebuild. The
cap is enforced on `articles` with no regard for what `saved_articles` references — there is no
foreign key and no "pinned" flag — and the rebuild is a destructive wipe-and-reinsert rather than a
targeted update, so omission is indistinguishable from deletion.

**Impact**

A user who saves an older article and then reaches the cache cap loses that article from their
Saved list on the next cloud sync. Preconditions: cache at/near 1000 rows, the saved article
outside the newest 1000, and a signed-in user whose sync produces at least one upsert or unsave.
Rare at current scale but **silent, permanent, and user-visible** — and increasingly likely as the
cache fills over time. There is no recovery path: the user has no record that the article existed.

**Blast radius on already-affected installs.** Any user who has already hit this has lost articles
with no trace — there is no backup to restore from, since the row is gone from both tables and the
cloud mirror only carries `isRead`/`isSaved` state for rows the user touched, not the article
itself. The fix prevents future loss; it cannot undo past loss. Worth stating plainly so the
priority is understood: this is a prevention fix, not a repair.

**Implementation**

Make the rebuild additive so a row can never be removed by omission:

```dart
// lib/services/cloud_sync_service.dart:237-242
if (merge.toUpsert.isNotEmpty || merge.toUnsave.isNotEmpty) {
  final merged = await _storage.loadArticles();
  final savedRows = merged.where((a) => a.isSaved).toList()
    ..sort((a, b) => b.pubDate.compareTo(a.pubDate));
  // Union with the rows already in saved_articles. Rebuilding from the feed
  // table ALONE silently deleted any saved article that saveArticles had
  // capped out of `articles` — the row vanished from the user's Saved tab
  // with no error. Anything already saved is user data; only an explicit
  // unsave (applied above via unsaveArticleLocally) may remove it.
  final known = await _storage.loadSavedArticles();
  final seen = {for (final a in savedRows) a.id};
  final keptSaved = <Article>[
    ...savedRows,
    for (final a in known)
      if (!seen.contains(a.id)) a,
  ]..sort((a, b) => b.pubDate.compareTo(a.pubDate));
  await _storage.saveSavedArticles(keptSaved);
  if (!_articlesRestored.isClosed) _articlesRestored.add(null);
}
```

Belt-and-braces — stop the cap from orphaning saved rows in the first place:

```dart
// lib/services/feed_database.dart:122-129
final sorted = List<Article>.from(articles)
  ..sort((a, b) {
    final c = b.pubDate.compareTo(a.pubDate);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });
// Never evict a row that saved_articles still references. Evicting it
// orphans the saved row, and the cloud-sync rebuild — which reads the feed
// table — would then delete it outright (F-1).
final savedIds = <String>{
  for (final r in await db.query(_savedTable, columns: ['id']))
    r['id'] as String,
};
final kept = <Article>[];
for (final a in sorted) {
  if (kept.length >= AppConfig.maxCachedArticles && !savedIds.contains(a.id)) {
    continue;
  }
  kept.add(a);
}
```

That change lets the cache exceed 1000 by the number of saved rows — the correct trade, since saved
data outranks cache size. Note the two fixes are complementary and neither is sufficient alone: the
union rebuild protects rows already orphaned by an older build, while the eviction guard stops new
orphans. Ship both.

**Verification**

Add alongside the existing `test/unit/services/feed_database_clock_test.dart`:

1. Seed 1001 articles with the oldest one saved.
2. `saveArticles`, then `upsertSavedArticle(old)`.
3. Run the rebuild logic and assert `loadSavedArticles()` **still** contains `old`.
4. Assert `loadArticleTimestamps()` still contains `old`.

**Regression risk**

`saved_articles` can now exceed `maxCachedArticles` by design. `maxCachedArticles` is referenced
in exactly one place (`feed_database.dart:123`), so there is no second cap to adjust. Confirm the
saved grid (`BentoSavedArticlesGrid`) renders acceptably with a large saved list.

---

### [MEDIUM] F-2 · Cloud Sync Silently Revokes Pro Purchased on Another Device

| | |
|---|---|
| **Endpoint** | Firestore `users/{uid}` (push side) |
| **Affected Component** | `CloudSyncService._pushSettings` |
| **Confidence** | source-level |
| **Note** | Same root cause as M-1 — **closed by the same fix** |

**Evidence.** Three writes combine to produce the defect, each individually reasonable:

| Location | Line(s) | Contribution |
|---|---|---|
| `cloud_sync_service.dart` | 361 | `'isPro': values['is_pro'] == true` — derives an authoritative field from a preference |
| `cloud_sync_service.dart` | 362 | `SetOptions(merge: true)` — overwrites without recording the change |
| `cloud_sync_service.dart` | 384–393 | `setPro` writes `isPro: true` — the value being clobbered |

`grep -n "isPro" lib/services/cloud_sync_service.dart` returns exactly 4 hits — read at `:133`
(`_ensureUserDoc` default) and `:285` (`_restoreProFlag`), written at `:361` (`_pushSettings`) and
`:388` (`setPro`). **Two of the four are writes, and they disagree on the source of truth** — which
is F-2 in one line.

**Affected source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/services/cloud_sync_service.dart` | 354–364 | `_pushSettings` writes `isPro` derived from the local preference |
| `lib/services/settings_service.dart` | 382 | `is_pro` is in `_syncedBoolKeys`, so it is in the snapshot |
| `lib/services/cloud_sync_service.dart` | 384–393 | `setPro` — the authoritative writer |
| `lib/services/cloud_sync_service.dart` | 278–297 | `_restoreProFlag` reads it back |

**Description**

`_pushSettings` runs on every settings change (3 s debounce) and writes the Pro flag back to the
user document **derived from the local preference**:

```dart
// lib/services/cloud_sync_service.dart:354-364
Future<void> _pushSettings(String uid) async {
  final now = _now();
  final values = await _settings.snapshotForSync();
  await _settingsDoc(uid).set({'values': values, 'updatedAt': now});
  await _settings.setSettingsSyncTs(now);
  // Keep the account-level Pro flag aligned with the settings snapshot.
  await _userDoc(uid).set({
    'isPro': values['is_pro'] == true,      // <-- local pref overwrites purchase state
    'updatedAt': now,
  }, SetOptions(merge: true));
}
```

`setPro` (`cloud_sync_service.dart:384-393`) is meant to be the authoritative writer — it records
`isPro: true` alongside `proProductId` and `proPurchaseToken`. But any later settings push from a
device whose *local* `is_pro` is still `false` overwrites that field back to `false`.

**Reproduction**

1. Device A signs in and buys Pro → local pref `true`; `setPro()` writes `users/{uid}.isPro = true`.
2. Device B signs in to the same account and has **not** completed its first sync — its local
   `is_pro` is `false`.
3. On device B, change any synced setting (toggle a theme, change the reader font).
   `onSettingsChanged` fires → 3 s debounce → `_pushSettings` writes `isPro: false`.
4. Device A's next sync reads `isPro == false`; `_restoreProFlag` returns early at
   `cloud_sync_service.dart:286` → **Pro is gone on device A**. The user paid and lost the feature.

The same push also writes `'updatedAt': now` to the user document, advancing the account clock on
every preference change — itself unnecessary write amplification.

**Root cause**

Identical to M-1: the entitlement is carried in a client-writable channel. M-1 is the direction
where an attacker gains; this is the direction where a legitimate payer loses. Two writers, one
untrusted input.

**Impact**

A paying user can lose Pro by toggling a theme on a second device. Revenue-affecting and
user-visible — the paywall reappears after a purchase already made. No security exposure.

**Implementation**

Covered by the M-1 fix (remove `is_pro` from `_syncedBoolKeys`). Additionally, stop the
authoritative field being derived from an untrusted mirror:

```dart
// lib/services/cloud_sync_service.dart:354-364
Future<void> _pushSettings(String uid) async {
  final now = _now();
  final values = await _settings.snapshotForSync();
  await _settingsDoc(uid).set({'values': values, 'updatedAt': now});
  await _settings.setSettingsSyncTs(now);
  // Do NOT mirror isPro back onto the user doc. `setPro` is the only writer
  // of that field; re-deriving it from the local preference meant a second,
  // not-yet-synced device could silently revoke a purchase made elsewhere
  // (its local values['is_pro'] was still false).
}
```

If the account-level flag ever needs periodic reconciliation, it must be LWW against the
**purchase record** (`proProductId` / `proPurchaseToken`), never against a preference mirror.

**Verification**

1. `snapshotForSync()` output contains no `is_pro` key.
2. Device-simulated: `_pushSettings` after a purchase does not flip `users/{uid}.isPro` to `false`.
3. Regression: `setPro` → `_restoreProFlag` still restores Pro on a fresh device.

**Regression risk**

Low. The user document stops receiving redundant writes, which is the point.

---

## 5. Low Findings

---

### [LOW] L-1 · Rate Limiter Is a Non-Atomic KV Read-Modify-Write

| | |
|---|---|
| **Endpoint** | `GET /articles`, `GET /sources` |
| **Affected Component** | `consumeRate` |
| **Confidence** | **live-verified** |

**Source location** — `workers/feed-worker.js:180-187`

```js
async function consumeRate(env, key, limit, windowSec) {
  const win = Math.floor(Date.now() / (windowSec * 1000));
  const k = `rl:${key}:${win}`;
  const cur = await env.ARTICLES_KV.get(k, 'json');
  if (cur && cur.n >= limit) return false;
  await env.ARTICLES_KV.put(k, JSON.stringify({ n: (cur?.n ?? 0) + 1 }),
                            { expirationTtl: windowSec * 2 });
  return true;
}
```

**Endpoint / Method / Component:** `GET /articles`, `GET /sources` · GET · `consumeRate`
(`workers/feed-worker.js:180-187`)

**Confidence:** **live-verified**

**Description.** KV `get`, increment in JS, `put` back. Cloudflare KV offers no compare-and-swap,
so concurrent requests inside one window all read the same value and overwrite each other.

**Evidence.** From a fresh 60-second window, 300 fully-concurrent `GET /sources` requests
(nominal limit 60/min):

| Run | `200` | `429` | Notes |
|---|---|---|---|
| 1 | **67** | 140 | exceeded the limit |
| 2 | 60 | 140 | at the limit |
| 3 | 48 | 102 | partial window already consumed by a prior probe |

Sequential baseline: 12 sequential requests → 12 × `200`, as expected.

**Root cause.** Read-modify-write on an eventually-consistent store without atomicity. The worker
already documents awareness of this class of problem elsewhere — `announceNewArticles`
(`feed-worker.js:639-641`) carries an explicit comment about KV lacking compare-and-swap and works
around it with an "announced" marker key.

**Impact.** Overshoot of roughly 10% under burst (67 of 300 concurrent requests passed a 60/min
limit). Both endpoints are unauthenticated reads over a shared cache, so the realistic worst case is
minor cost amplification, not a security bypass.

**Implementation**

Preferred — move throttling to an atomic primitive:

```toml
# workers/wrangler.toml
[[unsafe.bindings]]
name = "RATE_LIMITER"
type = "ratelimit"
```

```js
// workers/feed-worker.js
async function consumeRate(env, key, limit, windowSec) {
  const id = env.RATE_LIMITER.idFromName(key);
  const limiter = env.RATE_LIMITER.get(id);
  return await limiter.limit({ key, limit, period: windowSec });
}
```

Accepted alternative — if the project prefers no new bindings, keep KV but **document the limit as
advisory** so nobody treats it as a hard control:

```js
// ponytail: KV has no compare-and-swap, so this counter is advisory under
// concurrent burst (measured ~10% overshoot). Do not rely on it as a hard
// control; use a Rate Limiting binding if that ever matters.
```

**Verification.** Re-run the 300-concurrent probe; `200` count must not exceed the nominal limit.

**Regression risk.** A Rate Limiting binding is a structural change to worker config and requires a
`wrangler.toml` update plus a redeploy. The advisory-documentation path is zero-risk.

---

### [LOW] L-2 · Missing Security Headers on Worker Responses

| | |
|---|---|
| **Endpoint** | All worker routes |
| **Affected Component** | `cors()` response wrapper |
| **Confidence** | **live-verified** |

**Source location** — `workers/feed-worker.js:920-927`

```js
function cors(response) {
  const r = new Response(response.body, response);
  r.headers.set('Access-Control-Allow-Origin', CORS_ALLOWED_ORIGIN);
  r.headers.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  r.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-api-secret');
  return r;
}
```

**Endpoint / Method / Component:** all worker routes · all · `cors()` response wrapper
(`workers/feed-worker.js:920-927`)

**Confidence:** **live-verified**

**Evidence — headers observed on `GET /health`:**

```
HTTP/2 200 OK
Content-Type: application/json
Content-Length: 30
Access-Control-Allow-Origin: https://curated-feeds-worker.raj15400881.workers.dev
Access-Control-Allow-Headers: Content-Type, Authorization, x-api-secret
Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS
Report-To: {...}      <- Cloudflare edge
Nel: {...}            <- Cloudflare edge
Server: cloudflare    <- Cloudflare edge
```

Absent: `Strict-Transport-Security`, `X-Content-Type-Options`, `X-Frame-Options`,
`Content-Security-Policy`, `Referrer-Policy`, `Permissions-Policy`.

**Description.** Every response is `application/json` over HTTPS to a native client, so exposure is
limited. `X-Content-Type-Options: nosniff` is the header with any practical teeth here. Note that
`Access-Control-Allow-Origin` is a **fixed** constant (`feed-worker.js:59`), not reflected from the
request — so there is no CORS bypass.

**Impact.** Negligible for a JSON API consumed by a native app. Included because the fix is three
lines in one function and the headers are the cheapest hardening available.

**Root cause.** Only CORS headers were ever added to the shared wrapper.

**Implementation**

```js
function cors(response) {
  const r = new Response(response.body, response);
  r.headers.set('Access-Control-Allow-Origin', CORS_ALLOWED_ORIGIN);
  r.headers.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  r.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-api-secret');
  // Baseline hardening: this worker only ever returns application/json over
  // TLS, so nosniff + HSTS + no-referrer are the applicable subset.
  r.headers.set('X-Content-Type-Options', 'nosniff');
  r.headers.set('Referrer-Policy', 'no-referrer');
  r.headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  return r;
}
```

**Verification.** Request any route; confirm the three headers are present.

**Regression risk.** None. Do **not** add `X-Frame-Options` / `CSP` expecting an effect — these are
JSON API responses, not documents.

---

### [LOW] L-3 · No Length Cap on the `q` Search Parameter

| | |
|---|---|
| **Endpoint** | `GET /articles?q=` |
| **Affected Component** | `parseArticleParams` |
| **Confidence** | **live-verified** |

**Source location** — `workers/feed-worker.js:228-246`

```js
const pageSize = Number.isFinite(sizeRaw) ? Math.min(100, Math.max(1, sizeRaw)) : 50;  // clamped
const q = (url.searchParams.get('q') || '').trim();                                    // NOT clamped
const category = (url.searchParams.get('category') || '').trim();                      // NOT clamped
```

**Description.** `pageSize`, `since`, `until`, and `sort` are all clamped or allowlisted. The
free-text parameters are not. `q` is then evaluated against every cached article by
`applyFilters` (`feed-worker.js:252-282`).

**Evidence.** `GET /articles?q=<4000 × 'a'>&pageSize=1` → `200`,
`{"items":[],"total":0,"hasMore":false}`. Processed without error and without truncation.

**Root cause.** The clamp list covers numeric and enum parameters but not free-text ones.

**Impact.** Minor per-request CPU amplification on an unauthenticated endpoint. **No injection
surface** — `applyFilters` uses `String.includes`, not regex, so there is no ReDoS exposure.

**Implementation**

```js
function parseArticleParams(url) {
  // ...existing numeric clamps...
  // Free-text params are attacker-controlled and unbounded; cap them so a
  // single request cannot force an arbitrarily long scan.
  const q = (url.searchParams.get('q') || '').trim().slice(0, 200);
  const category = (url.searchParams.get('category') || '').trim().slice(0, 64);
  const sources = (url.searchParams.get('source') || '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean)
    .slice(0, 50);
  // ...
}
```

**Verification.** Add to `workers/test/feed-worker.test.js`:

```js
test('parseArticleParams truncates over-long free-text params', () => {
  const p = parseArticleParams(
    new URL(`https://x/articles?q=${'a'.repeat(500)}&category=${'b'.repeat(200)}`),
  );
  assert.equal(p.q.length, 200);
  assert.equal(p.category.length, 64);
});
```

**Regression risk.** None — no legitimate search query approaches 200 characters. Confirm the
existing `parseArticleParams` tests (`workers/test/feed-worker.test.js`) still pass; the added
`.slice()` calls must not alter the clamp behaviour for in-range values.

---

### [LOW] L-4 · Release Build Silently Falls Back to Debug Signing

| | |
|---|---|
| **Endpoint / Method / Component** | n/a (build configuration) · n/a · `android/app/build.gradle.kts` |
| **Affected Component** | Release artifact signing (Gradle `buildTypes.release`) |
| **Confidence** | source-level |

**Evidence.** `keystoreConfigured` is derived from whether `android/key.properties` parses
(`build.gradle.kts`, top of file):

```kotlin
val keystoreProperties = Properties().apply {
  val f = rootProject.file("key.properties")
  if (f.exists()) FileInputStream(f).use { load(it) }
}
val keystoreConfigured = keystoreProperties.getProperty("storeFile") != null
```

With no `key.properties`, `keystoreConfigured` is `false` and the release block below selects the
debug signing config. `key.properties` is gitignored, so a fresh clone always takes this path.

**Source location** — second `buildTypes` block

```kotlin
buildTypes {
  release {
    // Falls back to debug signing when key.properties is missing so
    // local release builds still work — never ship that APK.
    signingConfig = if (keystoreConfigured)
      signingConfigs.getByName("release")
    else
      signingConfigs.getByName("debug")
  }
}
```

**Description.** When `android/key.properties` is absent, `flutter build apk --release` succeeds and
emits an APK signed with the debug key. The comment says "never ship that APK," but nothing enforces
it — the build succeeds and produces a plausible-looking artifact that could be uploaded to GitHub
Releases or a store by mistake.

**Root cause.** A convenience fallback with no guard rail at the point where the risk materializes.

**Impact.** A debug-signed release APK is re-signable by anyone and cannot upgrade an existing
install in place. CircleCI always writes `key.properties` via `decode_signing`
(`.circleci/config.yml:69-81`), so **CI output is unaffected** — this is a local-build footgun and
a supply-chain hygiene issue rather than an active exposure.

**Implementation**

```kotlin
buildTypes {
  release {
    // Fail closed: a release build without real signing material must not
    // silently produce a debug-signed artifact. Opt in explicitly for local
    // smoke tests with -PallowDebugSigning.
    signingConfig = if (keystoreConfigured) {
      signingConfigs.getByName("release")
    } else if (project.hasProperty("allowDebugSigning")) {
      signingConfigs.getByName("debug")
    } else {
      throw GradleException(
        "android/key.properties is missing. Refusing to build a release " +
        "artifact signed with the debug key. Provide real signing material, " +
        "or pass -PallowDebugSigning for a local smoke test."
      )
    }
  }
}
```

**Verification.** `flutter build apk --release` without `key.properties` must fail with the message
above.

**Regression risk.** Breaks local release smoke tests that rely on the fallback. The
`-PallowDebugSigning` escape hatch keeps those working when wanted.

---

### [LOW] L-5 · Flaky Test: `paywall_screen_test.dart`

| | |
|---|---|
| **Endpoint / Method / Component** | n/a (test) · n/a · `test/unit/screens/paywall_screen_test.dart:72` |
| **Affected Component** | CI test reliability — no production code path |
| **Confidence** | **live-verified** (failure reproduced) |
| **Classification** | CI reliability, not a product defect |

**Source location** — `test/unit/screens/paywall_screen_test.dart:85-97`

```dart
// Let _loadStore() complete (fake isAvailable() returns false
// immediately) and the unavailable state render.
await tester.pump();
await tester.pump();

expect(
  find.text('Store unavailable. Check your connection and Play Store.'),
  findsOneWidget,
);
```

**Reproduction.** Approximately 30 full `flutter test` runs → **3 failures**, always in the full
parallel suite:

| Configuration | Result |
|---|---|
| Full suite, default concurrency | **failed 3 of ~25 runs** |
| Isolated file, 10× sequential | 10/10 pass |
| Isolated file, 4× parallel × 5 rounds | 20/20 pass |
| Full suite, `--concurrency=1`, 8 runs | 8/8 pass |

The failure surfaces only as a `Failing tests:` entry — the assertion detail did not appear in
`compact`, `expanded`, or `json` reporter output across every capture attempt, so the exact
assertion remains unpinned. This is worth flagging as an open question rather than papered over: the
proposed fix below addresses the most likely cause, but the mechanism is inferred from the
reproduction pattern, not observed.

**Description.** The test pumps a fixed number of frames after an async state transition and then
asserts on rendered text.

**Root cause.** Two bare `pump()` calls are a fixed guess at how many frames an async state
transition needs. `_loadStore()` is async and the screen starts in `_busy`; under CPU contention
from parallel suites the assumption fails. The onboarding test already documents this class of
problem in a comment (`onboarding_screen_test.dart:91-92`: *"we avoid pumpAndSettle here because
google_fonts runtime font loading can add network timers that make it flaky"*).

**Evidence.** Reproduction matrix above — fails only under parallel load, never in isolation or
serial. That pattern is characteristic of a frame-timing assumption rather than a logic error: the
assertion's *subject* is deterministic (the fake platform always returns `isAvailable() == false`),
only its *timing* varies.

**Impact.** CI is intermittently red on a green codebase — trains the team to ignore failures.
It also masks genuine regressions.

**Implementation**

```dart
// Bounded settle instead of a fixed pump count. _loadStore() is async and the
// screen starts in _busy; two bare pumps were a guess that failed under
// parallel-suite CPU contention (~1 in 10 full runs).
await tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),   // hard bound: the paywall's controllers
);                               // settle at 600ms/500ms, so this is ample.
```

**Verification.** Run the full suite 20+ times; the failure must not recur.

**Regression risk.** `pumpAndSettle` can hang on unbounded animation — hence the explicit timeout
argument. The paywall's `_drawController` (600 ms) and `_revealController` (500 ms) both settle, so
the bound is generous.

---

### [LOW] F-3 · Tombstone Map Grows Without Bound — `pruneDeletions` Is Dead Code

| | |
|---|---|
| **Endpoint** | Firestore `users/{uid}/sync_state/main` |
| **Affected Component** | `sync_merge.pruneDeletions` — defined and unit-tested, never called |
| **Confidence** | source-level |

**Evidence.** `grep -rn pruneDeletions` returns exactly two hits repo-wide:

```
lib/services/sync_merge.dart:74:Map<String, int> pruneDeletions(   ← definition
test/unit/services/sync_merge_test.dart:95: final pruned = ...     ← the only caller
```

Neither is a production call site.

**Source location**

| File | Line(s) | Role |
|---|---|---|
| `lib/services/sync_merge.dart` | 72–83 | `pruneDeletions` — 90-day cap. **Never called.** |
| `test/unit/services/sync_merge_test.dart` | 92–102 | tests it — the only caller |
| `lib/services/cloud_sync_service.dart` | 213–216 | reads `deletions`, never prunes |
| `lib/services/cloud_sync_service.dart` | 317–329 | `onSavedArticleRemoved` merges a new tombstone in |

**Description**

Every unsave writes a tombstone that is **never removed**:

```dart
// lib/services/cloud_sync_service.dart:322-328
await _syncStateDoc(uid).set({
  'deletions': {id: _now()},          // SetOptions(merge: true) — grows forever
}, SetOptions(merge: true))
```

`pruneDeletions` exists precisely for this — its own docstring says *"Drop tombstones older than
`maxAge` so the deletions map cannot grow without bound."* It is exported, pure, unit-tested, and
wired into nothing.

**Evidence** — `grep -rn pruneDeletions` across the repo returns exactly two hits: the definition
in `lib/services/sync_merge.dart` and its test in `test/unit/services/sync_merge_test.dart`. No
call site in `lib/`.

This is the clearest example in the codebase of a coverage illusion: the function has a passing
test, so the suite is green, while the behaviour the test was written for is never exercised in
production.

**Root cause**

A helper was written and tested as part of the merge logic, then the call site was never added to
`_reconcileArticles`. The test passes, so the gap is invisible to CI.

**Impact**

One map entry per unsaved article, growing for the life of the account. Each `syncNow` reads the
whole map (`cloud_sync_service.dart:213-216`), and each unsave rewrites it. Firestore documents cap
at 1 MiB; at roughly 40 bytes per entry that is ~25 000 unsaves before the write starts failing —
unlikely to hit, but the map never shrinks and the read cost is paid on every single sync
regardless. For a heavy reader this is the dominant cost of `_reconcileArticles`.

**Implementation**

```dart
// lib/services/cloud_sync_service.dart:213-216
final stateData = (await _syncStateDoc(uid).get()).data();
final deletionsRaw = ((stateData?['deletions'] as Map?) ?? const {}).map(
  (k, v) => MapEntry(k as String, (v as num).toInt()),
);
// Bound the tombstone map. pruneDeletions already implements the 90-day
// cap and is unit-tested, but was never wired in — the map grew by one entry
// per unsave for the life of the account.
final deletions = pruneDeletions(deletionsRaw, _now());
if (deletions.length != deletionsRaw.length) {
  await _syncStateDoc(uid).set({'deletions': deletions}, SetOptions(merge: true));
}
```

Requires importing `pruneDeletions` from `sync_merge.dart` (already imported for `mergeArticles`).

**Verification** The existing `pruneDeletions` tests already cover the function; add one
integration-shaped test asserting the map does not grow past the window after N unsaves.

**Regression risk**

None. A tombstone older than 90 days is already meaningless — the article it refers to has long
since rotated out of the feed cache. Do **not** lower `maxAge` below the sync interval or a
legitimate unsave could be forgotten before it propagates.

---

### [LOW] F-4 · Cloud Sync Reads the Entire Article Collection on Every Launch

| | |
|---|---|
| **Endpoint** | Firestore `users/{uid}/articles` |
| **Affected Component** | `CloudSyncService._reconcileArticles` |
| **Confidence** | source-level |

**Evidence.** The read is unconditional and unfiltered at `cloud_sync_service.dart:198`; the only
filter in the whole reconcile path is on the *push* side:

```dart
// lib/services/cloud_sync_service.dart:251-256
final toPush = [
  for (final a in all)
    if ((a.isRead || a.isSaved) && (localTs[a.id] ?? 0) > (cloudTs[a.id] ?? 0))
      a,
];
```

There is no equivalent `where` clause on the read. `syncNow` is invoked from
`CloudSyncService.init` → `authStateChanges` (`cloud_sync_service.dart:70-80`), which fires once per
process start while signed in.

**Source location** — `lib/services/cloud_sync_service.dart:197-211`

```dart
Future<void> _reconcileArticles(String uid) async {
  final cloudSnap = await _articlesCol(uid).get();      // ← no limit, no pagination
  final cloudTs = <String, int>{};
  final remote = <RemoteArticle>[];
  for (final d in cloudSnap.docs) {
    final data = d.data();
    final ts = (data['updatedAt'] as int?) ?? 0;
    cloudTs[d.id] = ts;
    remote.add(RemoteArticle((data['payload'] as Map?)?.cast<String, dynamic>() ?? const {}, ts));
  }
  // ... merge, upsert, rebuild saved, push back ...
}
```

**Description**

`syncNow` runs on **every app start** while signed in (`service_locator.dart:65` →
`authStateChanges` → `syncNow`), and on every sign-in. Each run pulls the full
`users/{uid}/articles` collection with no `limit` and no pagination.

Only rows the user has touched are ever pushed — `(a.isRead || a.isSaved)` at
`cloud_sync_service.dart:251-256` — so the collection grows by one document per article the user
marks read or saves, and never shrinks. A reader who triages a few hundred articles per month
accumulates a few hundred documents, all re-read on every cold start.

**Root cause**

The push side is already selective (`isRead || isSaved`); the pull side was not given the same
treatment. There is no marker distinguishing "touched by the user" from "default unread", so the
client cannot ask for less.

**Impact**

Firestore bills per document read. This is the single largest recurring cloud cost in the app and
it scales linearly with usage rather than with active state. It also lengthens cold-start latency
proportionally — the read happens before the feed renders.

**Implementation**

There is **no cheap fix**, and it is worth being blunt about why. Firestore cannot filter a
collection query server-side on "changed since T" without either (a) a composite index and an
inequality filter, which is not supported on document fields, or (b) a query constraint the client
does not have. The read has to be expressed somehow.

Two honest options:

**Option A — accept it and document it.** For an app at this scale the cost is likely immaterial.
Record the intent so nobody assumes it is bounded:

```dart
// lib/services/cloud_sync_service.dart:197-198
/// Reconciles the user's triage state against the cloud.
///
/// Reads the FULL `users/{uid}/articles` collection. Every document in it
/// exists because the user touched that article (the push filter is
/// `isRead || isSaved`), so the collection only ever grows and the read cost
/// scales with lifetime triage volume, not current state. Firestore offers
/// no way to query "changed since" on a document field, so bounding this
/// requires the structural change in Option B. Measured acceptable at the
/// current user volume — revisit if the bill or cold-start latency grows.
Future<void> _reconcileArticles(String uid) async {
  final cloudSnap = await _articlesCol(uid).get();
```

**Option B — collapse to one document.** Store clocks in a single `sync_state` map (the same shape
already used for tombstones) and keep payloads only where they differ from the feed cache:

```dart
// Conceptual shape — NOT a drop-in patch.
// users/{uid}/sync_state/main
//   { "articles": { "<id>": {"t": <clock>, "s": 0|1, "r": 0|1} }, "deletions": {...} }
// Payloads are then reconstructable from the local feed cache, which already
// holds every article by id — so only the *triage flags* need to live in the
// cloud, not the full article JSON.
```

This cuts the per-sync read to **one** document regardless of user age, and it merges naturally
with the existing tombstone map (F-3's fix touches the same document). The cost is a schema
migration and a rewrite of `_pushArticles` / `_reconcileArticles`.

**Recommendation:** Option A now, Option B only if Firestore usage becomes material. Option B is a
real refactor and should not be done speculatively — but note that it is the *same document*
F-3 already touches, so if both are done they should be done together.

**Verification** Not testable without an emulator. Confirm via Firestore usage metrics over a week
of real syncs before committing to Option B.

**Regression risk** Option B is a schema change: every existing `users/{uid}/articles/*` document
would need migration, and a partial migration would silently lose triage state. Not worth doing
without measured justification.

---

### [LOW] F-5 · Edition-Counter Bump Writes to the Cloud on Every Refresh

| | |
|---|---|
| **Endpoint / Method / Component** | Firestore `users/{uid}/settings/main` · POST (SDK) · `SettingsNotifier.bumpEdition` → `SettingsService` → `SyncHooks` |
| **Affected Component** | `feed_screen` refresh path → `SettingsService` → `SyncHooks` |
| **Confidence** | source-level |

**Evidence.** The trigger is one line in the refresh success path
(`lib/screens/feed_screen.dart:396-400`), reached on every successful refresh — auto-refresh timer,
pull-to-refresh, connectivity regain, and the initial load in `_loadData` (`feed_screen.dart:295`):

```dart
// Bump the editorial edition number on every successful refresh.
if (mounted) {
  final next = await context.read<SettingsNotifier>().bumpEdition();
  EditionState.current = next;
  setState(() {});
}
```

`bumpEdition` → `bumpEditionNumber` → `setEditionNumber` → `_setString`, and `_setString` is the
shared setter that fires the hook unconditionally (`settings_service.dart:40-46`). Meanwhile
`edition_number` is deliberately **absent** from `_syncedStringKeys` (`settings_service.dart:364-374`)
— the exclusion is expressed only on the read path.

**Source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/screens/feed_screen.dart` | 396–400 | every successful refresh calls `bumpEdition()` |
| `lib/providers/settings_notifier.dart` | 231–235 | `bumpEdition` |
| `lib/services/settings_service.dart` | 291–295 | `setEditionNumber` → `_setString` |
| `lib/services/settings_service.dart` | 40–46 | `_setString` fires `syncHooks?.onSettingsChanged()` |
| `lib/services/cloud_sync_service.dart` | 333–341 | debounced → `_pushSettings` |
| `lib/services/settings_service.dart` | 362 | `edition_number` deliberately **excluded** from the sync snapshot |

**Description**

The "edition number" in the masthead is a purely device-local counter — the comment at
`settings_service.dart:362` explicitly excludes it from the synced keys as "device-local state".
But it is written through `_setString`, which is the *shared* string setter, and that setter fires
the cloud-sync hook unconditionally:

```dart
// lib/services/settings_service.dart:40-46
Future<void> _setString(String key, String value) async {
  await init();
  await _prefs.setString(key, value);
  syncHooks?.onSettingsChanged();      // ← fires for edition_number too
}
```

So each successful feed refresh (auto-refresh timer, pull-to-refresh, connectivity regain, or the
initial load in `_loadData`) triggers a debounced `_pushSettings`, which writes **two** Firestore
documents (`settings/main` and `users/{uid}`) whose contents are byte-identical to the last push.

With a 30-minute default refresh interval that is ~48 pointless document writes per day per active
user, and it also advances `users/{uid}.updatedAt` each time.

**Root cause**

The device-local settings (`onboarding_complete`, `edition_number`) share a setter with the synced
settings. The exclusion is expressed in the *read* path (`snapshotForSync`) but not the *write* path,
so the hook cannot tell them apart.

**Impact**

Firestore write amplification, and a slightly misleading account clock. Not user-visible.

**Implementation**

```dart
// lib/screens/feed_screen.dart:396-400
final next = await context.read<SettingsNotifier>().bumpEdition();
EditionState.current = next;
```

with a dedicated setter that skips the hook:

```dart
// lib/services/settings_service.dart — after setEditionNumber
/// Device-local counter: deliberately NOT cloud-synced (see
/// snapshotForSync, which excludes it). Uses a raw write so a feed refresh
/// does not push two identical Firestore documents via the settings hook.
Future<void> bumpEditionNumber() async {
  await init();
  final next = (int.tryParse(_prefs.getString('edition_number') ?? '') ?? 0) + 1;
  await _prefs.setString('edition_number', next.toString());
}
```

**Verification**

Not testable without a Firestore emulator (none is configured). Cheapest check: add a temporary
counter to `_pushSettings`, log it at app close, and confirm it does not rise across refreshes.
Better long-term: assert in a unit test that `bumpEditionNumber` does not invoke `syncHooks`, by
injecting a recording `SyncHooks` double — that needs no emulator and locks the behaviour in.

**Regression risk**

None. `onboarding_complete` has the same issue (`setHasCompletedOnboarding` → `_setBool` → hook)
and could use the same treatment, but it fires once per install so it does not matter.

Note the interaction with F-2: every one of these pointless pushes also rewrites `users/{uid}.isPro`
from the local preference. Fixing F-1 (the data-loss one) is unrelated, but fixing **M-1** removes
this particular side effect as a side benefit, since `is_pro` will no longer be in the snapshot.

---

### [LOW] F-6 · "Max Articles: 2000" Is Unreachable — The Cache Caps at 1000

| | |
|---|---|
| **Endpoint / Method / Component** | n/a (local setting) · n/a · Settings UI vs. `AppConfig.maxCachedArticles` |
| **Affected Component** | `settings_screen` dropdown · `FeedDatabase.saveArticles` |
| **Confidence** | source-level |

**Evidence.** The two limits are declared in different files and never reconciled:

```dart
// lib/screens/settings_screen.dart:958 — display preference, max offered 2000
value: [100, 250, 500, 1000, 2000].contains(settings.maxArticles)
    ? settings.maxArticles : 500,
```

```dart
// lib/utils/constants.dart:111 — storage budget, fixed at 1000
static const int maxCachedArticles = 1000;
```

`grep -rn maxCachedArticles lib/` returns **one** executable consumer, and it is a hard `take()`
with no relationship to the preference (the other two hits are doc comments):

```
lib/utils/constants.dart:111:          static const int maxCachedArticles = 1000;
lib/services/feed_database.dart:111:   /// doc comment — "The newest-[AppConfig.maxCachedArticles]"
lib/services/feed_database.dart:129:   final kept = sorted.take(AppConfig.maxCachedArticles).toList();
lib/services/feed_database.dart:165:   /// doc comment — "[AppConfig.maxCachedArticles] rows on every swipe"
```

`max_articles` is applied only at read time in `feed_screen.dart:379`
(`articles.take(maxArticles)`), so a value above 1000 is a no-op rather than an error.

**Source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/screens/settings_screen.dart` | 957–964 | dropdown offers `[100, 250, 500, 1000, 2000]` |
| `lib/screens/feed_screen.dart` | 375–379 | `articles.take(maxArticles)` on read |
| `lib/services/feed_database.dart` | 123–129 | `sorted.take(AppConfig.maxCachedArticles)` on write |
| `lib/utils/constants.dart` | 111 | `maxCachedArticles = 1000` |

**Description**

The Settings dropdown offers 2000 as the maximum-articles option. The display path honours it
(`feed_screen.dart:379`), but the storage path does not:

```dart
// lib/services/feed_database.dart:123
final kept = sorted.take(AppConfig.maxCachedArticles).toList();   // hard 1000
```

`maxCachedArticles` is a compile-time constant of 1000 and is referenced in exactly one place.
A user who selects 2000 gets at most 1000 articles, with no indication that the setting did
nothing.

The two limits are also conceptually different — `max_articles` is a *display* preference,
`maxCachedArticles` is a *storage* budget — and nothing in the UI or the code acknowledges that.

**Root cause**

The storage cap was introduced independently of the display setting and never reconciled with it.

**Impact**

A dead setting option. Minor, but it is the kind of thing that generates "the 2000 option doesn't
work" bug reports. Note the interaction with F-1: the storage cap is what orphans saved rows in the
first place, so the two findings share a root — and F-1's eviction guard widens the cache to
`1000 + |saved|`, which makes the gap between the offered display values and the storage budget
*larger*, not smaller. If the guard lands first, the dead option becomes more misleading.

**Implementation**

Either drop the option, or make the storage budget follow the preference:

```dart
// lib/screens/settings_screen.dart:958 — simplest honest fix
value: [100, 250, 500, 1000].contains(settings.maxArticles)
    ? settings.maxArticles
    : 500,
```

Preferred, if the larger cache is actually wanted — raise the storage ceiling and let the display
preference be the real control:

```dart
// lib/utils/constants.dart:111
/// Storage ceiling for the feed cache. Independent of the `max_articles`
/// DISPLAY preference (settings_screen.dart) — that one trims what is shown,
/// this one bounds what is kept. Must be >= the largest offered display
/// value or the setting silently caps.
static const int maxCachedArticles = 2000;
```

**Verification** Set 2000, refresh until the cache is full, assert `loadArticles().length` reaches
2000.

**Regression risk** Raising the storage ceiling doubles worst-case cache size and slows
`saveArticles`, which rewrites the whole table on every refresh. Given F-1 is fixed by exempting
saved rows from eviction, raising the ceiling is the cleaner long-term shape — but measure.

---

## 6. Informational

| ID | Item | Location | Note |
|---|---|---|---|
| **I-1** | `debugPrint` active in direct release builds | `lib/main.dart:22-26` | Silenced **only** for Play builds. Direct builds log worker URLs and error text to logcat, readable over `adb` on a non-rooted device. Consider silencing in all release builds. |
| **I-2** | Play `purchaseToken` persisted to Firestore | `lib/services/cloud_sync_service.dart:384-393` | The account owner's own data, and rules prevent cross-user reads. But a purchase token is a redeemable credential — consider whether it needs to persist at all. |
| **I-3** | `matchingTokens` is O(subscribers) per refresh | `workers/feed-worker.js:713-728` | One KV `get` per row inside the 5-minute cron. Fine at current scale; compounds M-2. |
| **I-4** | Sentry `tracesSampleRate` set twice | `lib/main.dart:70` (`1.0`) then `:83` (`0.1`) | Cascade semantics mean the last assignment wins, so behaviour is correct. The `1.0` is dead code. |
| **I-5** | Live secrets in `env.txt` on an external NTFS volume | `env.txt` | `GITHUB_TOKEN`, keystore passwords, `WORKER_API_SECRET`. **Correctly gitignored and untracked.** Full git history searched for key patterns, `env.txt`, `key.properties`, `*.jks`, `google-services.json` — all clean. Worth keeping off shared volumes. |
| **I-6** | No Firestore rules tests in CI | `firestore.rules` | Deployed but never exercised. M-1 lives precisely in this uncovered area. |
| **I-7** | No published GitHub releases | `STRK-ND/feedapp` | **Confirmed 2026-10-07:** `GET /releases/latest` → **HTTP 404**. The OTA path has never run against a live release. The verification code is correct but untested against a real artifact — relevant because `direct`-channel users currently have no update mechanism at all. |
| **I-8** | `isReaderThemeLocked` hardcodes Pro themes | `lib/utils/reader_theme.dart:102-103` | Sepia and e-ink are locked. This is the product decision M-1 monetises; no change proposed. |
| **I-9** | Custom-source id hash can collide | `lib/models/rss_source.dart:91-97` | `stableIdForUrl` is a 30-bit hash. Two distinct feed URLs can collide, producing two sources with the same id. `addCustomSource` dedupes by *URL*, not id, so the collision survives — and `ClientFeedService._build` derives article ids as `${source.id}-${hash(link)}`, so colliding sources produce **colliding article ids**, meaning articles from one feed overwrite the other in SQLite (`id` is PRIMARY KEY). Low probability (~1 in 10⁹ per pair), but the consequence is silent article loss. Worth widening the hash or validating uniqueness at insert time. |
| **I-10** | Worker compression works — Burp's header view is misleading | `feed-worker.js:913-918` | Burp reports `content-encoding=ABSENT` because it transparently decodes responses. `curl` with `Accept-Encoding: gzip` returns `content-encoding: gzip`. Measured on `pageSize=100`: identity **127,191 bytes** → gzip **28,792 bytes** (4.4× reduction). **Not a defect.** Recorded so the next person to probe with Burp does not file a false positive. See [§12.2](#122-disproved-hypothesis-recorded-so-it-is-not-re-investigated). |

---

### 6.1 Data-Layer Findings Not Filed as Separate Entries

Recorded here rather than as numbered findings because they are either covered by a larger entry
or are deliberate design trade-offs already documented in the source.

| Item | Location | Assessment |
|---|---|---|
| `FeedDatabase` path is always prefixed with `getDatabasesPath()`, so an absolute path is silently re-rooted | `feed_database.dart:51-56` | **Not a product bug** — correct for the app. It did mislead the first migration probe, which is why it is noted. |
| `saveArticles` captures row clocks in a `db.query` **outside** the transaction, and swallows a failure into an empty map | `feed_database.dart:133-143` | Narrow. If that query throws, every reinserted row gets `updated_at = 0`, which means "remote wins" in the merge — the next sync re-pulls the whole collection and re-pushes touched rows. Write amplification, no data loss. The `catch` comment (*"treating as empty"*) shows the degradation is deliberate but its consequence is not documented. |
| `saveArticles` reads the clock map, then deletes and reinserts — a concurrent `upsertArticle` between the two is clobbered | `feed_database.dart:133-157` | Narrow window (milliseconds, between one `query` and the transaction). `ArticleRepository.syncFrom` shares `Article` object references with the feed screen, so triage mutations do propagate — the exposure is limited to a tap landing exactly inside the window. |
| Legacy blob migration retries on every `loadArticles` when it fails | `storage_service.dart:182-214` | `_migrationChecked = false` in the `catch` means each subsequent load re-reads secure storage. Two extra `read` calls per refresh on a permanently-failing migration. Self-limiting and harmless. |
| The migration marker is written before the legacy blobs are deleted | `storage_service.dart:203-206` | If the deletes fail, the blobs are orphaned in secure storage. Harmless — they are redundant after migration — but they are never cleaned up. |
| Custom feed fetches are unbounded in count | `article_repository.dart:214-220` | One `Future.wait` over every active custom source, each with an 8 s timeout and a 5 MB cap. A user with many feeds pays all of them on every refresh. `Future.wait` means one slow source delays the batch, though `.catchError` keeps a failure from failing the rest. |
| `upsertSavedArticle` rewrites every row's `position` on each new save | `feed_database.dart:230` | `UPDATE saved_articles SET position = position + 1` is O(n) per save. At realistic saved-list sizes this is fine; at F-1's uncapped saved list it becomes worth revisiting. |
| OPML import is capped at `maxXmlSizeBytes` (5 MB) | `sources_screen.dart:490-496` | Correct. Parsed with `XmlDocument.parse`, which does not resolve external entities — no XXE. |
| `sources_screen.dart:192` uses `firstWhere` with no `orElse` | `sources_screen.dart:192-194` | Safe today: `addCustomSource` either adds the URL or returns a list already containing it, and `getCustomSources` only drops records that fail `RssSource.fromJson` — which would have dropped the just-added row too. But the `submit()` closure has no `try`/`catch`, so any future change that breaks the invariant produces an unhandled async error rather than a user-facing message. |

---

## 7. Verified Not Vulnerable

Recorded so these are not re-audited.

### Authentication & Authorization

- **Worker authorization fails closed.** `isAuthorized` (`feed-worker.js:133-156`) returns `false`
  when `API_SECRET` / `ADMIN_SECRET` is unset. **Live-verified**: `PUT /sources`,
  `POST /subscribe`, and `GET /articles/refresh` all returned `401` with no header, an empty
  header, and a wrong header.
- **Admin authority is separated from the app secret.** `PUT /sources` returned `401` with the
  app-level secret. Pinned by test at `workers/test/feed-worker.test.js:479`.
- **No privilege escalation surface exists** — there are no roles, admin accounts, or RBAC anywhere
  in the app. The only privilege concept is the local Pro flag (M-1).
- **No IDOR/BOLA.** The worker serves one global public feed; Firestore rules scope every document
  to `request.auth.uid`. No per-object identifier a user can swap.
- **No tenant concept** to isolate — single-tenant by design.

### Input Validation

- **No SQL injection.** `feed_database.dart` uses parameterized `whereArgs` throughout. No
  string-concatenated SQL anywhere.
- **No command injection.** No `Process.run`, no shell invocation, no process spawning in `lib/`.
- **No XSS.** No WebView, no `javascript:` execution, no HTML rendering. `stripHtml` / `cleanText`
  strip tags before display; content renders as Flutter `Text`.
- **No XXE.** The worker parses XML with regex, not a real parser. The client's `package:xml` does
  not resolve external entities.
- **No path traversal.** OPML import matches URLs only against the canonical list
  (`lib/utils/opml.dart:40-42`). The OTA filename is sanitized (`update_service.dart:288`) and
  written under `getTemporaryDirectory()`.
- **No SSRF.** The only server-side fetch is the worker fetching configured RSS URLs. `/subscribe`
  accepts a token but triggers no outbound request.
- **No CRLF/header injection.** Query params are only used in comparisons, never echoed into
  headers.
- **Prototype pollution not reachable.** `GET /articles?__proto__[x]=1` → `200` with normal data.
  `URLSearchParams` does not create object properties; `applyFilters` builds a `Set` of strings.
- **Method and path handling clean.** `PUT /subscribe`, `DELETE /sources`, `POST /articles` →
  `404`. `TRACE` → `405` at the edge. Case-sensitive (`/ARTICLES` → `404`), trailing-slash strict
  (`/articles/` → `404`), encoded traversal (`/articles%2f..%2fsources` → `404`).
- **Numeric and enum params clamped.** `pageSize=99999` → clamped to 100. `page=-5` → clamped to 1.
  `sort` allowlisted to three values. No negative slice index reachable. The *free-text* params
  (`q`, `category`, `source`) are not clamped — that is L-3, an amplification issue rather than a
  bypass.
- **Token shape validated.** `POST/DELETE /subscribe` require 10–4096 chars
  (`feed-worker.js:300, 331`); pinned by test at `workers/test/feed-worker.test.js:541`.

### File Handling

- **No upload functionality exists.**
- **OTA integrity chain is sound.** `downloadApk` (`update_service.dart:235-359`) resolves the
  expected SHA-256 *before* spending the download, hashes the streamed bytes via a chunked
  conversion, throws on mismatch, and refuses to rename to an installable name. The 100 MB cap is
  enforced both on `content-length` and mid-stream. `triggerInstall` refuses any handle where
  `installable` is false (`:369-377`).
- **Open-in-browser is scheme-restricted** to http/https (`expanded_article_card.dart:454-456`),
  blocking `intent://` and other app-handoff schemes.
- **OPML import caps file size** at `AppConfig.maxXmlSizeBytes` (`sources_screen.dart:490-496`).

### Data Layer (pass 2)

Verified by reading, and — where noted — by instrumented probe.

- **Parameterized SQL throughout.** No string concatenation into any query, in any of the ~20
  statements in `feed_database.dart`.
- **`ConflictAlgorithm.replace` on every insert**, so re-running any write is idempotent rather
  than throwing on a primary-key collision.
- **Corrupt-row tolerance everywhere.** `_loadRows` (`feed_database.dart:341-362`),
  `_decodeArticleList` (`storage_service.dart:159-175`), and `mergeArticles`
  (`sync_merge.dart:48-53`) each catch a per-record decode failure and continue — one bad payload
  cannot empty the feed.
- **v1→v2 SQLite migration is correct.** Probe-verified: the `updated_at` column is added, legacy
  rows survive, and the value reads `0` as documented.
- **Row-clock preservation on the refresh path is correct.** Probe-verified — surviving rows keep
  their clocks, brand-new rows read `0`. This is the subtle invariant that prevents an infinite
  re-push loop, and it holds. (In F-1 the clock is lost because the row is *evicted*, not because
  preservation fails.)
- **The merge rules themselves are sound.** `sync_merge.dart` is pure and Firebase-free, which is
  why it is unit-testable; it has 14 passing tests. The defects in §4/§5 are in how callers *feed*
  and *consume* it, not in the merge.
- **Snapshot LWW is correct.** Remote wins only when strictly newer; the both-clocks-zero
  first-sync case pushes local. Verified against `remoteSnapshotWins`
  (`sync_merge.dart:88-89`) and its callers (`cloud_sync_service.dart:143-195`).
- **Tombstones correctly suppress stale remote docs** — a deletion newer than the doc skips the
  upsert (`sync_merge.dart:54-55`).
- **`clearFeedCache` cannot destroy user data.** It deletes only `articles` and leaves
  `saved_articles` intact (`storage_service.dart:251-260`), which is the documented intent and the
  right behaviour. F-1 is a *different* path (the sync rebuild), not this one.
- **Firestore batch size is respected** — 400 per batch, under the 500-document limit
  (`cloud_sync_service.dart:264`).
- **Untouched rows are not re-pushed.** The `isRead || isSaved` filter
  (`cloud_sync_service.dart:251-256`) is a deliberate and correct write-amplification guard.

### Response Transport (pass 3)

- **Compression works correctly.** Measured `pageSize=100`: identity **127,191 bytes** → gzip
  **28,792 bytes** (4.4×). Burp's `content-encoding: ABSENT` reading is Burp decoding
  transparently — see [I-10](#6-informational).
- **No compression-bomb risk.** `readTextCapped` (`feed-worker.js:840-863`) reads in chunks and
  cancels at `MAX_XML_BYTES` (5 MB) rather than buffering unbounded.
- **The retry ladder does not amplify load on success.** `WorkerFeedService` retries only non-200
  and non-429 responses (`worker_feed_service.dart:71-141`); a healthy `200` returns first attempt.
- **KV refresh is thundering-herd protected.** `REFRESH_LOCK_KEY` with a 60 s TTL
  (`feed-worker.js:359-371`) stops concurrent cron ticks each fetching all 12 RSS sources, and the
  `finally` at `:412-414` releases it even on throw.
- **Auto-refresh does not fire while backgrounded.** `_armAutoRefresh` schedules a single
  one-shot timer and `didChangeAppLifecycleState` cancels it on pause
  (`feed_screen.dart:152-159`), so the Dart isolate is not waking the radio on a background timer.

### Configuration & Deployment

- **Release provenance gate works.** Tags must be ancestors of `origin/master`
  (`.circleci/config.yml:170-191`), plus a manual approval hold, plus a pinned `FLUTTER_COMMIT`
  verified against the cloned SDK SHA.
- **`--dart-define` expansions are quoted** in CI, preventing shell word-splitting of secrets.
- **No secrets in git history**, across all refs.
- **`allowBackup="false"`** in the manifest — app data is not extractable via `adb backup`.
- **`POSTHOG_AUTO_INIT=false`** in the manifest, so the native SDK cannot initialize without a key.

---

## 8. Code-to-HTTP Correlation

### 8.1 Pro self-grant (M-1)

```
Attacker writes Firestore doc (own account, permitted by firestore.rules:9-14)
    ↓
PATCH users/{uid}/settings/main
  body: { updatedAt: <future>, values: { is_pro: true } }
    ↓
Firestore security rules — ALLOW
  request.auth.uid == uid ✓          ← rules scope by identity only, not by field
    ↓
App launch / sign-in
    ↓
lib/di/service_locator.dart:65 → CloudSyncService.init()
    ↓
lib/services/cloud_sync_service.dart:70-80  authStateChanges → syncNow()
    ↓
lib/services/cloud_sync_service.dart:104     await _reconcileSettings(user.uid)
    ↓
lib/services/cloud_sync_service.dart:144-145 read doc; cloudTs = updatedAt
    ↓
lib/services/cloud_sync_service.dart:151     if (cloudTs > localTs)          ← attacker sets future clock
    ↓
lib/services/cloud_sync_service.dart:154     await _settings.restoreFromSync(values)
    ↓
lib/services/settings_service.dart:419-422   for (k in _syncedBoolKeys)     ← 'is_pro' is in this list (:382)
    ↓
lib/services/settings_service.dart:421       await _prefs.setBool('is_pro', true)   ← NO GATE
    ↓
lib/services/cloud_sync_service.dart:156     await _restoreProFlag(uid)
    ↓
lib/services/cloud_sync_service.dart:285-286 cloudPro == false → return EARLY
                                          (local flag already true; never cleared)
    ↓
HTTP: none — entitlement is entirely client-side
    ↓
UI: Pro features unlock on Play build with no purchase
```

**Where the control fails:** `settings_service.dart:419-422`. The write into local storage is the
trust boundary and has no gate. `firestore.rules` cannot help — it correctly scopes by identity,
and the attacker *is* the identity.

### 8.2 Subscription write amplification (M-2)

```
POST /subscribe  { "token": "<unique per request>" }
  Header: x-api-secret: <extracted from release APK>
    ↓
workers/feed-worker.js:101  url.pathname === '/subscribe' && method === 'POST'
    ↓
workers/feed-worker.js:102  isAuthorized(request, env)
    ↓
workers/feed-worker.js:151-155  API_SECRET configured + secretsMatch() → true
                              (secret is in the APK; assumption is public by design)
    ↓
workers/feed-worker.js:294-301  body parsed; token length 10..4096 ✓
    ↓
workers/feed-worker.js:306  consumeRate(env, 'sub:' + token + subIp, 10, 60)
                             ↑ CALLER-CONTROLLED in the key → limit is per-token, not per-caller
    ↓
workers/feed-worker.js:311  KV.put(`sub:${token}`, {...}, { expirationTtl: 90 days })
    ↓
... later, on any refresh that finds new articles ...
    ↓
workers/feed-worker.js:405  announceNewArticles(articles.slice(0, 3), env)
    ↓
workers/feed-worker.js:664  matchingTokens(env, categories)
    ↓
workers/feed-worker.js:718  KV.list({ prefix: 'sub:' })        ← grows with injected rows
    ↓
workers/feed-worker.js:720  KV.get(name, 'json')  × N           ← one read per subscription
```

**Where the control fails:** `feed-worker.js:306` (and `:336` for DELETE). The limiter is keyed on
a parameter instead of the caller, so it bounds the wrong subject.

### 8.3 Push registration failure (M-3)

```
App launch → NotificationService.initialize()
    ↓
lib/services/notification_service.dart:167  NotificationService.enablePushNotifications()
    ↓
lib/services/notification_service.dart:72   POST {workerApiUrl}subscribe
    Header: x-api-secret: <WORKER_API_SECRET compiled at build time>
    ↓
workers/feed-worker.js:102  isAuthorized(request, env)
    ↓
workers/feed-worker.js:155  secretsMatch(provided, env.API_SECRET) → false (stale build value)
    ↓
HTTP 401 {"error":"unauthorized"}
    ↓
lib/services/notification_service.dart:90-93  throw StateError('Push subscription failed: HTTP 401')
    ↓
lib/services/notification_service.dart:167-171 .catchError(...) → debugPrint only
    ↓
User: no push notifications. No error surfaces. No alert fires.
```

**Where the control fails:** not a security control — a *observability* gap at
`notification_service.dart:167-171`. The 401 is treated identically to any transient failure and
discarded.

---

### 8.4 Saved-article loss (F-1)

```
User saves an article older than the newest 1000
    ↓
Feed refresh → ArticleRepository.fetchNewArticles()
    ↓
lib/repositories/article_repository.dart:174-179   mergedArticles = existing + new
    ↓
lib/services/storage_service.dart:35-41            saveArticles(mergedArticles)
    ↓
lib/services/feed_database.dart:145-157
  DELETE FROM articles                              ← the saved-but-old row is evicted
  reinsert newest 1000 with preserved clocks
  (saved_articles is NOT touched — the row is now orphaned)
    ↓
… next app launch, user signed in …
    ↓
lib/di/service_locator.dart:65                     CloudSyncService.init()
    ↓
lib/services/cloud_sync_service.dart:70-80         authStateChanges → syncNow()
    ↓
lib/services/cloud_sync_service.dart:104           _reconcileArticles(uid)
    ↓
lib/services/cloud_sync_service.dart:225-229       upsertArticles(merge.toUpsert, clocks:)
    ↓
lib/services/cloud_sync_service.dart:237           if (toUpsert.isNotEmpty || toUnsave.isNotEmpty)
    ↓
lib/services/cloud_sync_service.dart:238           merged = loadArticles()   ← articles table only
    ↓
lib/services/cloud_sync_service.dart:241           saveSavedArticles(merged.where(isSaved))
    ↓
lib/services/feed_database.dart:280                DELETE FROM saved_articles
    ↓
lib/services/feed_database.dart:281-293            reinsert — the orphaned row is GONE
    ↓
UI: article silently disappears from the Saved tab. No error, no undo.
```

**Where the control fails:** `cloud_sync_service.dart:238`. The rebuild reads one table but is
expected to represent the union of two. The eviction that creates the orphan is at
`feed_database.dart:146`.

### 8.5 Pro revoked on a second device (F-2)

Same trigger as §8.1 (a user preference change), opposite outcome.

```
Device A: purchase Pro
    ↓
lib/screens/paywall_screen.dart:132                notifier.setIsPro(true)      → local pref true
    ↓
lib/screens/paywall_screen.dart:136-139            CloudSyncService.setPro(...)
    ↓
lib/services/cloud_sync_service.dart:387-391       users/{uid}.isPro = true      ← authoritative
    ↓
… device B signs in, has not synced, local is_pro = false …
    ↓
User toggles a theme on device B
    ↓
lib/services/settings_service.dart:40-46           _setString → syncHooks.onSettingsChanged()
    ↓
lib/services/cloud_sync_service.dart:336-339       3s debounce → _pushSettings(uid)
    ↓
lib/services/cloud_sync_service.dart:361           'isPro': values['is_pro'] == true   → FALSE
    ↓
Firestore users/{uid}.isPro  true → false          purchase record overwritten
    ↓
Device A next sync → cloud_sync_service.dart:285-286  cloudPro == false → return
    ↓
UI on device A: Pro gone. The user paid.
```

**Where the control fails:** `cloud_sync_service.dart:361`. An authoritative field is derived from
an untrusted mirror, and `merge:true` makes the overwrite silent.

---

## 9. Data-Layer Deep Debug (Pass 2)

Pass 1 was security-led and read the data layer only to answer authorization questions. Pass 2
instrumented it directly.

### 9.1 Method

1. Read every file in the persistence path end to end: `feed_database.dart`, `storage_service.dart`,
   `sync_merge.dart`, `cloud_sync_service.dart`, `settings_service.dart`,
   `article_repository.dart`.
2. Wrote four throwaway probe tests against an in-memory `sqflite_common_ffi` database to observe
   actual behaviour rather than infer it.
3. Ran 25–30 full `flutter test` passes to characterise the flaky test statistically.
4. Traced every write path into `SharedPreferences` for unintended cloud-sync side effects.

The probe file was **deleted** after use — see [§14](#14-files-touched-by-this-audit). Nothing it
touched remains in the repository.

### 9.2 Probe results (verbatim)

```
PROBE A: articles rows=1000
PROBE A: saved rows=1
PROBE A: OLD-SAVED present in articles table? false      → F-1
PROBE A: OLD-SAVED present in saved_articles? true
PROBE A: OLD-SAVED has a clock entry? false

PROBE B: clock before=1791358205706 after=1791358205706  → clock preservation works
PROBE B: brand-new row clock=0 (expect 0)

PROBE C: articles columns=[id, pub_date, payload, updated_at]   → v1→v2 migration OK
PROBE C: legacy row survived migration? true
PROBE C: legacy updated_at=0 (expect 0)

PROBE D: articles=1000 clockHasOld=false clockValue=null   → confirms F-1's second-order effect
PROBE D: -> merge would treat local clock as 0; a remote doc with any updatedAt>0 wins
```

**PROBE B is a negative result and matters as much as the positive ones:** the existing
`updated_at` clock-preservation contract in `saveArticles` (`feed_database.dart:153`) works
correctly. The clock is lost in F-1 only because the row is *evicted*, not because preservation
fails. That narrows the fix.

**PROBE C clears the migration path.** A hand-built v1 database migrates correctly: the column is
added, the row survives, and `updated_at` reads `0` as documented. No finding.

Two probe iterations were needed and both are worth recording, because both would have produced
false results:

- The first cap probe used 999 filler rows instead of 1000, so the total was exactly 1000 and the
  target row was never evicted — a **false negative** that looked like "the bug does not exist".
- The first migration probe used `inMemoryDatabasePath` across a `close()`/`open()` cycle. In-memory
  databases do not survive that, so it silently tested a fresh v2 database and reported the legacy
  row as missing — a **false positive** that would have become a bogus "migration destroys user
  data" finding. It was re-run against `FeedDatabase.migrate` directly, which cleared it.

Both are the standard failure mode of probe-based verification: a probe that does not actually
exercise the code path it claims to.

### 9.3 What the data layer got right

Worth recording, because these are the parts a naive rewrite would break:

- **Parameterized SQL throughout.** No string concatenation into any query.
- **`ConflictAlgorithm.replace` on every insert**, so a re-run is idempotent rather than throwing.
- **Corrupt-row tolerance.** `_loadRows` (`feed_database.dart:341-362`) catches a decode failure per
  row and continues — one bad payload does not empty the feed. Same pattern in
  `_decodeArticleList` (`storage_service.dart:159-175`) and in `mergeArticles`
  (`sync_merge.dart:48-53`).
- **The v1→v2 migration is correct and verified** (PROBE C).
- **Clock preservation on the refresh path is correct** (PROBE B), which is the subtle part — a
  naive `saveArticles` would stamp `now` on every row and cause an infinite re-push loop. The
  existing comment at `feed_database.dart:113-119` shows this was a deliberate design decision.
- **The merge is pure and Firebase-free** (`sync_merge.dart`), which is why it is unit-testable at
  all. 14 unit tests cover it.
- **Batched pushes at 400** (`cloud_sync_service.dart:264`), under Firestore's 500-document limit.

---

## 10. Test & Analysis Results

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **PASS** — 0 issues |
| Format gate | `dart format --output=none --set-exit-if-changed lib test` | **PASS** — 94 files, 0 changed |
| Flutter tests | `flutter test` | **PASS** — 251/251 in 22 of 25 runs; **1 flaky** in 3 |
| Worker tests | `node --test` (in `workers/`) | **PASS** — 32/32 |
| Data-layer probes | 4 throwaway tests (deleted) | Reproduced F-1; cleared the migration path |
| Worker payload composition | `GET /articles?pageSize=100` | **Measured** — P-1 confirmed, 100/100 duplicates |
| Worker latency | 20 sequential requests × 4 endpoints | **Measured** — P-3 confirmed (446ms @ pageSize=1) |
| Compression | `curl` identity vs gzip | **PASS** — gzip works, 4.4× (see §12.2) |
| GitHub rate limit | `curl -I .../releases/latest` | **Measured** — `x-ratelimit-limit: 60` |
| Security headers | Burp on all routes | **Measured** — P-6, L-2 confirmed |
| Monetisation funnel | Source trace of cap-hit → paywall | **Measured** — R-1: 1 paywall entry point, 0 cap-hit routes to it |
| Account deletion | `grep deleteAccount\|deleteUser\|accountDeletion` | **Measured** — R-2: 0 hits in `lib/` and `android/` |
| Funnel analytics | Enumerate `AnalyticsService` events | **Measured** — R-3: 16 events, 0 paywall/purchase |
| In-app review | `grep in_app_review` | **Measured** — R-4: not a dependency |
| Artifact size | `ls -la` on built APK/AAB | **Measured** — R-5: 65.6 MB APK, 66.0 MB AAB, 3 ABIs |
| Store metadata | `ls fastlane metadata store-listing` | **Measured** — R-6: all absent |
| OTA endpoint liveness | `curl -o /dev/null -w %{http_code}` | **Measured** — I-7 confirmed: `releases/latest` → 404 |
| Frame timing / jank | DevTools | **NOT RUN** — no device (P-7) |
| Battery attribution | `dumpsys batterystats` | **NOT RUN** — no `adb` (P-7) |
| Isolate churn | DevTools / logcat | **NOT RUN** — no device (P-7) |
| Release build | `flutter build apk --release` | **NOT RUN** — no Android SDK on host |
| Firestore rules | emulator suite | **NOT RUN** — no emulator configured |

**Flaky failure detail** (L-5): `paywall_screen_test.dart: renders store-unavailable state when
the store is not available`. Reproduced 3 times across ~25 full runs; 10/10 in isolation, 20/20
under 4-way parallel load, 8/8 with `--concurrency=1`. The assertion detail never appeared in
`compact`, `expanded`, or `json` reporter output, so the exact assertion remains unpinned.

No test failures were caused by any change, because this audit changed nothing.

---

## 11. Remediation Plan

Ordered by value-to-effort. All items are independent **except** where noted.

| # | Finding | Effort | Risk if fixed | Priority |
|---|---|---|---|---|
| 1 | **F-1** Saved-article data loss | ~12 lines + test | Saved list can exceed the cache cap by design | **Do first — only data-loss finding** |
| 2 | **M-1** + **F-2** Pro entitlement (one root cause) | ~4 lines + test | Pro stops syncing via the settings doc — verify `setPro` | **Do first** |
| 3 | **M-3** Secret drift | Operational | None — adds an alert path | **Do first** |
| 4 | **M-2** Per-token rate limit | 2 lines + test | NAT'd users share one bucket | High |
| 5 | **L-5** Flaky test | ~3 lines | `pumpAndSettle` needs a timeout bound | High (CI trust) |
| 6 | **F-3** Wire up `pruneDeletions` | ~4 lines | None | Medium |
| 7 | **F-5** Edition bump sync hook | ~5 lines | None | Medium |
| 8 | **L-2** Security headers | 3 lines | None | Medium |
| 9 | **L-3** `q` cap | 3 lines | None | Medium |
| 10 | **F-6** Dead 2000 option | 1 or 2 lines | Raising the cache ceiling doubles worst-case DB size | Medium |
| 11 | **L-4** Debug-signing guard | ~8 lines | Breaks local release smoke tests | Medium |
| 12 | **F-4** Bounded article pull | Structural | Larger change — measure first | Low / decide |
| 13 | **L-1** Atomic rate limiter | Config + code | Structural change to worker | Low / decide |
| 14 | **I-6** Firestore rules tests | New test suite | None | Worthwhile |
| 15 | **P-2** Restore the update-check throttle | 1 line | Auto-check drops to hourly (the documented intent) | High — cheapest real win |
| 16 | **P-1** Stop sending `fullContent` | ~6 lines + test | Wire format change — needs Option A, not B | High — 26% bandwidth |
| 17 | **P-6** Cache headers + ETag | ~6 lines | None — Dart client does not HTTP-cache | Medium — same function as L-2 |
| 18 | **P-4** Bound `matchingTokens` scan | ~4 lines | Tail subscribers get delayed pushes (already capped at 500) | Medium |
| 19 | **P-3** Skip redundant full sort | ~6 lines | Depends on an implicit cache-ordering invariant | Medium |
| 20 | **P-5** Parallelise dedupe reads | ~6 lines | Writes must stay serial — do not "optimise" them too | Low |
| 21 | **P-7** Profile, then decide | Tooling | n/a — measurement first | Profile before changing anything |

**Sequencing notes**

- Items **1** and **2** are independent of each other but both touch `cloud_sync_service.dart`.
  Do them as separate commits so a regression in one is easy to bisect.
- Items **4, 6, 7, 8, 9** are all small and non-overlapping — batch into one commit, one test run.
- Item **3** is an ops task and can proceed in parallel with everything.
- Items **12** and **13** deserve a decision, not immediate work — both are structural, and both have
  an acceptable "document it and move on" option.
- **P-6 should ride along with L-2.** Both edit the same `cors()` helper at
  `feed-worker.js:920-927`. Doing them as one commit avoids touching the function twice.
- **P-1 and P-2 are the cheapest real wins in this report** — one line and six lines respectively,
  both independently verifiable, neither requiring structural change. P-2 restores a throttle that
  was already written and already tested; P-1 removes data that is provably duplicated.
- **P-3's fast-path rests on an implicit invariant** — that the cached array is always persisted
  `pubDate DESC`. It holds today (`feed-worker.js:474`) but nothing enforces it. If you take P-3,
  add a comment at the KV `put` site stating the invariant, or the optimization becomes a latent
  correctness bug the next time someone changes the sort.

**On P-1's rollout.** Option A (stop sending the field, keep it readable) is safe on its own. Option
B (delete it) is not: an older installed client would read `fullContent` as empty and degrade to
fetching full content for *every* article. Take Option A now; revisit B behind a minimum-version
floor.

**On P-7.** Profile before touching anything in that list. Several entries carry comments claiming
measured CPU savings — `client_feed_service.dart` and `article_content_service.dart` both cite
mid-range-phone profiling for their `Isolate.run` calls. It would be a mistake to "optimise" those
without re-measuring.

**Cross-finding interactions worth knowing before you start**

- **M-1 fixes F-2, and partially F-5.** All three route through `is_pro` being in the synced
  snapshot. One change, three findings closed. Do M-1 first and re-assess F-2 and F-5 afterwards —
  F-2 may need nothing beyond it.
- **F-1 needs both of its sub-fixes.** The union rebuild protects rows *already* orphaned by a
  shipped build; the eviction guard prevents *new* orphans. Neither alone is sufficient.
- **F-3 and F-4 share a document.** F-3 prunes `sync_state/main.deletions`; F-4's Option B
  collapses the article mirror into that same document. If both are done, do them together.
- **L-4 gates nothing else** but should land before any public release, since it is the only
  control preventing a mis-signed artifact from reaching users.

**On F-6:** the two options are not equivalent. Dropping the dead dropdown entry is a 1-line honest
fix. Raising `maxCachedArticles` to 2000 fixes the symptom but doubles worst-case cache size and
slows `saveArticles` (a full-table rewrite per refresh). Given F-1 is being fixed by exempting saved
rows from eviction, raising the ceiling is the better long-term shape — but measure before doing it.

**Regression checklist for any batch**

```bash
flutter analyze                                    # must stay at 0 issues
flutter test                                       # expect 251 passing, 0 failing
(cd workers && node --test)                        # expect 32/32
dart format --output=none --set-exit-if-changed lib test
grep -rn "is_pro\|isPro" lib/ test/                # confirm intent of every remaining hit
grep -rn "maxCachedArticles" lib/                  # confirm the cap and its uses stay in sync
grep -rn "fullContent" lib/ workers/               # P-1: confirm no stale reader remains
```

For the F-1 fix specifically, add a regression test that seeds >`maxCachedArticles` articles with
the oldest one saved, then asserts it survives both `saveArticles` and the sync rebuild. That test
is the whole point of the fix — without it, the same regression returns silently.

For P-1, add a worker test asserting the emitted article object has no `fullContent` key, and a
payload assertion that `pageSize=100` shrinks by roughly 26% of raw bytes.

For P-2, add a test that calls `checkForUpdates()` twice and asserts the second issues no HTTP
request — the throttle is already implemented and currently untested.

---

### 11.1 Revenue-Priority Ranking

Pass 4 re-ranked every finding against the stated goal — **earn revenue, grow users** — rather than
security severity. The two orderings disagree, and the difference is the point of this subsection.
It covers all 27 numbered findings; the top 10 are shown, the remainder defer to the effort table
above.

Security severity asks *"how bad is this if abused?"* Revenue priority asks *"how much money or
retention does this cost, and how cheap is the fix?"*

| Rank | Finding | Why it ranks here | Effort |
|---|---|---|---|
| **1** | **R-1** Cap-hit shows a SnackBar, never the paywall | The only moment a user has *demonstrated intent to pay*, and the app does not ask. Every other fix defends revenue already being collected; this one collects revenue currently being dropped on the floor. | 2 sites × 1 line |
| **2** | **R-2** No account deletion flow | Blocks Play submission and every subsequent update. No revenue until this is fixed. | ~60 lines |
| **3** | **M-1 + F-2** Pro entitlement self-grant + self-revoke | You cannot reliably charge for Pro while a user can grant it to themselves, *and* a paying customer can lose it. Revenue in, revenue out. | ~4 lines |
| **4** | **R-3** Zero funnel analytics | Without this you cannot tell whether R-1 worked, so you cannot tune it. Instrument *before* optimising. | ~20 lines |
| **5** | **F-1** Saved articles silently deleted | The only data-loss finding. Costs retention and produces the 1-star review that suppresses ranking. | ~12 lines |
| **6** | **R-4** No in-app review prompt | Ratings are a ranking input. Cheapest growth lever available — no server, no policy risk. | ~15 lines + 1 dep |
| **7** | **M-3** Secret drift | Push notifications are silently dead for builds using the stale value. Push is a retention lever and it is currently off. | Operational |
| **8** | **P-2** Dead update throttle | Wasted request per cold start; update prompts silently stop when the shared-IP quota is exhausted. Affects retention indirectly. | 1 line |
| **9** | **P-1** 26% payload duplication | Data + battery cost on every refresh. Shows up as retention, not as a single visible defect. | ~6 lines |
| **10** | **L-5** Flaky test | Blocks confident shipping of the above. | ~3 lines |
| 11+ | M-2, P-3, P-4, F-3…F-6, L-1…L-4, P-5…P-7, R-5, R-6 | Real, but cost or hygiene rather than revenue. See §11 for effort detail. | — |

**The one-line version:** R-1 is the highest-value change in this entire report. It is two lines,
it has no regression risk, and no other finding on this list recovers revenue that is being
discarded at the moment of intent.

**Two findings move in opposite directions under this ranking:**

- **M-1/F-2 move UP.** Security severity called them Medium; as revenue defects they are worse,
  because they attack the *only* monetised surface the app has.
- **M-2 and P-4 move DOWN.** They are the most technically interesting findings in the report
  (KV rate-limit racing, attacker-inflatable key-space), but with a modest subscriber base they
  cost almost nothing. Fix them when convenient, not first.

---

## 12. Performance & Battery Findings (Pass 3)

Pass 3 used Burp Suite MCP to probe the deployed worker's response shapes, payload composition, and
latency, then correlated each observation with the client code that consumes it.

**Honest scope statement, up front.** Burp is an HTTP proxy. It can measure what crosses the wire —
bytes, header shape, latency, request patterns. It **cannot** measure frame rate, jank, isolate
churn, wake-lock duration, or actual mAh drain. This host has no `adb`, no emulator, and no Android
SDK, so every claim about *on-device* cost below is either derived from wire evidence (and labelled
as such) or explicitly marked **unmeasured**. Findings marked unmeasured are numbered rather than
buried, because an audit that silently omits the jank paths because it cannot measure them is not an
honest audit.

### 12.1 Finding Index (pass 3)

| ID | Severity | Finding | Confidence |
|---|---|---|---|
| **P-1** | Medium | `fullContent` duplicates `description` — 26% of every payload | **live-measured** |
| **P-2** | Medium | The hourly update-check throttle is dead; GitHub quota spent per cold start | **live-measured** |
| **P-3** | Medium | `/articles` latency scales with total cached articles, not page size | **live-measured** |
| **P-4** | Medium | `matchingTokens` is O(subscribers) KV GETs per cron cycle | source-level |
| **P-5** | Low | `announceNewArticles` does serial GET+PUT per article | source-level |
| **P-6** | Low | No `Cache-Control` / `ETag` / `Last-Modified` on any response | **live-measured** |
| **P-7** | Low | Client hot paths with plausible battery cost — **unquantified** | unmeasured |

---

### [MEDIUM] P-1 · `fullContent` Duplicates `description` — 26% of Every Payload

| | |
|---|---|
| **Endpoint** | `GET /articles` |
| **Affected Component** | Worker `buildArticle` + `Article` model + reader card |
| **Confidence** | **live-measured** on production data |

**Source locations**

| File | Line(s) | Role |
|---|---|---|
| `workers/feed-worker.js` | 579–580 | `description,` / `fullContent: description,` — the two fields are assigned the same value |
| `lib/models/article.dart` | 10, 29, 49 | `fullContent` is a distinct required field, serialised in `toJson` |
| `lib/widgets/expanded_article_card.dart` | 190, 195, 222 | reads `fullContent` |
| `lib/widgets/expanded_article_card.dart` | 116, 671–674 | renders `_fullContent ?? article.fullContent` |

**Description**

The worker assigns the *same string* to both `description` and `fullContent`:

```js
// workers/feed-worker.js:576-581
const description = strip(
  extractTag(body, opts.descTag) || extractTag(body, opts.fullContentTag)
);
return {
  id: stableId(source.id, link),
  title,
  description,
  fullContent: description,     // ← identical to the line above
  // ...
};
```

Both fields are then serialised to JSON and sent on every fetch.

**Evidence** — measured on live production data (`GET /articles?pageSize=100`, 126,499 raw bytes):

```
  description        :    32,910 bytes (26.0%)
  fullContent        :    32,910 bytes (26.0%)
  description === fullContent : 100/100
  author == null              : 90/100
  imageUrl == null            :   4/100
  fetchedFullContent == null  : 100/100
```

**The duplication is total, not partial — 100 of 100 articles.** Roughly a quarter of every feed
response is a byte-for-byte copy of another field in the same object.

The client is not blameless in the design: `expanded_article_card.dart:190` gates whether to fetch
the full article on `fullContent.length < 200`, so the field is load-bearing for a length heuristic
that `description.length` would answer identically.

**Root cause**

`fullContent` is a leftover from a design where the worker would eventually return the parsed article
body. It never did — the worker only ever has the RSS summary — so the field was populated with the
summary and the separate `description` field was added later without removing it.

**Impact**

26% bandwidth reduction available on every feed fetch, every refresh, every device. At the measured
page size that is ~33 KB saved per 100-article page (~379 KB across a 3-page full fetch, uncompressed;
~79 KB gzipped). On a metered mobile connection that is a direct, recurring data cost. It also costs
JSON parse time on the client for no benefit.

**Implementation**

Two options. The safe one is recommended for rollout:

**Option A (safe, recommended) — stop sending it, keep the field readable.**

```js
// workers/feed-worker.js:576-593
return {
  id: stableId(source.id, link),
  title,
  description,
  // `fullContent` intentionally omitted: it was always a byte-for-byte copy
  // of `description`, costing 26% of every payload. Clients treat it as
  // optional and fall back to `description`. Remove the key entirely only
  // once no deployed client reads it.
  link,
  // ...
};
```

```dart
// lib/models/article.dart:94 — tolerate the missing key (already does)
fullContent: json['fullContent'] as String? ?? '',
```

```dart
// lib/widgets/expanded_article_card.dart:190 — ask the surviving field
final summary = widget.article.description;
if (summary.length < 200) {
  await _fetchFullContent();
} else {
  if (mounted) setState(() { _fullContent = summary; });
}
```

Also drop the `fullContent` write in `client_feed_service.dart:170`
(`fullContent: description`) — same duplication on the custom-feed path.

**Option B (clean) — delete the field entirely** from the worker, the `Article` model, and all six
read sites. Correct long-term, but a wire-format break: an old client against a new worker still
works (it reads `description` for cards and `fullContent` for the reader — which would now be empty,
degrading the reader to fetching full content for *every* article). Do not do this without
coordinating a minimum-version floor.

**Verification**

Re-run the payload-composition measurement and assert `description === fullContent` no longer holds
for shipped articles; confirm `bytes` for `pageSize=100` drops by roughly 26%. Add a worker test
asserting the emitted object has no `fullContent` key. Confirm the reader still shows body text for a
short-`description` article (the `< 200` fetch path).

**Regression risk**

Option A is additive-safe: old clients keep working because `fullContent` is only *stopped being
sent*, and any client that has already cached an article still has the field locally. The one real
risk is a client that reads `fullContent` **without** a null guard — `article.dart:94` already
defaults to `''`, and the reader at `:116` already falls back, so the codebase is ready. Option B
risks older installed clients degrading to always-fetch; avoid it for now.

---

### [MEDIUM] P-2 · The Hourly Update-Check Throttle Is Dead

| | |
|---|---|
| **Endpoint** | `GET https://api.github.com/repos/STRK-ND/feedapp/releases/latest` |
| **Affected Component** | `FeedScreen.initState` → `UpdateService.checkForUpdates` |
| **Confidence** | **live-measured** |

**Source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/screens/feed_screen.dart` | 130 | `_checkForUpdates()` in `initState` — every widget construction |
| `lib/screens/feed_screen.dart` | 315 | passes `forceCheck: true` |
| `lib/services/update_service.dart` | 56–59 | `if (!forceCheck && ...) return null;` — the throttle, gated on the flag |
| `lib/services/curated_feeds_app.dart` | 190 | `IndexedStack` keeps `FeedScreen` alive across tab switches |

**Description**

`UpdateService.checkForUpdates` implements an hourly throttle keyed on `last_update_check`:

```dart
// lib/services/update_service.dart:56-59
if (!forceCheck && (now - lastChecked) < oneHourInMs) {
  return null;
}
```

But the only automatic caller — the one that runs on every app start — passes `forceCheck: true`,
which **disables the throttle entirely**:

```dart
// lib/screens/feed_screen.dart:308-316
Future<void> _checkForUpdates() async {
  if (AppConfig.isPlayStoreBuild) return;
  await Future<void>.delayed(Duration.zero);
  if (!mounted) return;
  final updateInfo = await UpdateService.checkForUpdates(forceCheck: true);
  // ...
}
```

The manual "Check for updates" menu item (`feed_screen.dart:1171`) also passes `forceCheck: true` —
correctly, since a user tapping it wants a real check. The problem is that the *automatic* call uses
the same flag.

**Evidence — GitHub's unauthenticated limit, measured live:**

```
$ curl -sI https://api.github.com/repos/STRK-ND/feedapp/releases/latest
  x-ratelimit-limit: 60
  x-ratelimit-remaining: 59
  x-ratelimit-reset: <epoch>
```

60 requests/hour per source IP, and the app sends **no `Authorization` header** — so it is subject
to the *unauthenticated* bucket (`update_service.dart:65` sets only `Accept`).

**Root cause**

`forceCheck` conflates two distinct intents: "the user explicitly asked" and "this is an automatic
background check." The throttle was written for the second case and then defeated by passing the
first case's flag.

**Impact**

- **Shared-IP exhaustion.** GitHub buckets by source IP. On carrier CGNAT, corporate NAT, or a
  university network, every Curated Feeds user behind that egress shares one 60/hour budget. A user
  whose check 404s (or any app on that IP) consumes the quota.
- **Silent failure.** When the limit is hit, GitHub returns `403`/`429`. `checkForUpdates` wraps
  everything in a `try/catch` that returns `null` (`update_service.dart:108-110`), so the user sees
  nothing — no update, no error, no retry. It degrades to "no updates available" silently.
- **Battery.** One extra HTTPS round-trip to a third party on every cold start, for a check whose
  result changes at most once per release.

**Note on severity.** This is *not* a self-inflicted denial of service on GitHub at meaningful
scale, and it does not affect Play builds (the check returns early at `feed_screen.dart:311`). It is
Medium because it is a correctness bug with a real third-party dependency and a silent failure mode,
not because the blast radius is large.

**Implementation**

```dart
// lib/screens/feed_screen.dart:308-316
Future<void> _checkForUpdates() async {
  if (AppConfig.isPlayStoreBuild) return;
  await Future<void>.delayed(Duration.zero);
  if (!mounted) return;

  // NO forceCheck here. The hourly throttle in checkForUpdates exists for
  // exactly this path — passing forceCheck:true disabled it, so every cold
  // start spent one of GitHub's 60 unauthenticated requests/hour. Those are
  // bucketed per source IP, so CGNAT/NAT users share one budget.
  final updateInfo = await UpdateService.checkForUpdates();
  if (mounted && updateInfo != null) {
    await showUpdateDialog(context: context, updateInfo: updateInfo);
  }
}
```

The manual menu item keeps `forceCheck: true` (`feed_screen.dart:1171`) — that is the correct use.

Two follow-ups worth considering:

```dart
// lib/services/update_service.dart — surface rate-limit exhaustion rather
// than swallowing it. Currently every error path returns null identically.
if (response.statusCode == 403 || response.statusCode == 429) {
  final reset = response.headers['x-ratelimit-reset'];
  unawaited(ErrorHandler.logError(
    'GitHub update check rate-limited (reset at $reset). '
    'Update notifications will be missed until then.',
    severity: ErrorSeverity.low,
  ));
  return null;
}
```

And consider authenticating the check with a token, or moving it to the worker cron (which already
runs every 5 minutes with a server-side identity), so the client stops making unauthenticated
third-party calls entirely.

**Verification**

Unit test: call `checkForUpdates()` twice in a row and assert the second returns `null` without
issuing a request (inject a recording `http.Client`). Add the `forceCheck: true` manual path as a
second case asserting it *does* issue a request.

**Regression risk**

Users who currently get an update prompt on every cold start will now get at most one per hour —
which is the documented intent. The residual risk is a user who never opens Settings and relies on
the auto-check; the hourly window is the same one the original code intended.

---

### [MEDIUM] P-3 · `/articles` Latency Scales With Total Cached Articles, Not Page Size

| | |
|---|---|
| **Endpoint** | `GET /articles` |
| **Affected Component** | `handleArticles` — filter + sort over the full cached array |
| **Confidence** | **live-measured** |

**Source location** — `workers/feed-worker.js:204-223`

```js
articles = applyFilters(articles, { q, since, until, category, sources });

// Copy before sort — with no filters active applyFilters returns the
// shared cached array.
const sorted = [...articles].sort(/* ...comparator... */);

const total = sorted.length;
const start = (page - 1) * pageSize;
const items = sorted.slice(start, start + pageSize);
```

The filter and the sort both run over **every cached article** before the page slice is taken. The
cost is therefore `O(n log n)` in the *total* cached count, independent of `pageSize`.

**Description.** `handleArticles` treats pagination as a presentation concern applied at the very end
of a pipeline that has already done full-dataset work. There is no index, no pre-sorted cache, and no
early exit for the common case where no filters are active and the default sort is requested.

**Evidence** — 20 sequential requests each, measured against production:

| Endpoint | Mean latency | Work performed |
|---|---|---|
| `/health` | **32.6 ms** | no KV, no filter, no sort |
| `/sources` | **475.8 ms** | 1 KV read, no filter |
| `/articles?pageSize=50` | **493.5 ms** | 1 KV read + filter + sort + slice |
| `/articles?pageSize=1` | **446.4 ms** | identical work, 1 item serialised |

The decisive line is the last one: **`pageSize=1` costs 90% of what `pageSize=50` costs.** The work
is in reading the KV value and sorting it, not in serialising the response. Requesting fewer items
does not make the request cheaper.

**Root cause**

Pagination is applied *after* an unconditional full-array sort. There is no index, no pre-sorted
cache, and no early exit.

**Impact**

Latency — and therefore Cloudflare CPU per request — grows with the size of the cached feed rather
than with the work actually requested. Today `total` is 264; at 2,000 articles the sort cost rises
roughly with `n log n`. Compounding this on the client:

```
lib/utils/constants.dart:75                workerTimeoutSeconds = 8
lib/services/worker_feed_service.dart:45   maxRetries = 3
lib/services/worker_feed_service.dart:46   baseDelayMs = 1000
```

A slow response can hold the radio for **8 s + 1 s + 8 s + 2 s + 8 s + 4 s + 8 s ≈ 39 s** across the
retry ladder before the user sees a failure, and `_refreshFeeds` is invoked from auto-refresh, from
connectivity-regain, and from pull-to-refresh (`feed_screen.dart:231, 267, 1109, 1503`).

**Implementation**

The cached array is already stored `pubDate DESC` — the default sort order. So for the default
`date_desc` path with no active filters, the sort is redundant and can be skipped:

```js
// workers/feed-worker.js:204-217
articles = applyFilters(articles, { q, since, until, category, sources });

// Default order is pubDate DESC, which is how the cache is persisted
// (fetchAllSources sorts before the KV put). Re-sorting it on every request
// is O(n log n) over the whole cache for a result we already have — and it
// made pageSize=1 cost 90% of pageSize=50 (measured: 446ms vs 493ms).
const needsSort = sort !== 'date_desc' || articles !== cachedArticles;
const sorted = needsSort ? [...articles].sort(comparatorFor(sort)) : articles;
```

Requires tracking whether `applyFilters` returned the shared array (it does — the existing comment
says so) and hoisting the comparator into a named function.

A larger, better fix: store a date-keyed index alongside the array, or cache the sorted array
separately so `date_desc` is a pure slice. That is a real refactor and should be driven by measurement,
not done speculatively.

**Client-side mitigation, independent of the worker:**

```dart
// lib/services/worker_feed_service.dart — do not retry a 200-class slowness.
// The current ladder retries ALL non-429 failures including plain timeouts,
// so a degraded-but-working worker costs 39s of radio. Retry only on
// transport errors and 5xx; surface a timeout to the user immediately.
```

**Verification**

Re-run the timing table. `pageSize=1` should drop materially. Add a worker test asserting that with
`sort` omitted and no filters, the cached array is returned by identity (no copy) — the existing
`applyFilters` comment already promises this behaviour.

**Regression risk**

The identity fast-path assumes the cache is always persisted `pubDate DESC`. That invariant holds
today (`fetchAllSources`, `feed-worker.js:474`) but is implicit — add a comment at the KV `put` site
stating it, or the optimization becomes a latent correctness bug when someone changes the sort.

---

### [MEDIUM] P-4 · `matchingTokens` Is O(subscribers) KV GETs Per Cron Cycle

| | |
|---|---|
| **Endpoint** | Internal — cron path, `announceNewArticles` |
| **Affected Component** | `matchingTokens` |
| **Confidence** | source-level |

**Source location** — `workers/feed-worker.js:713-728`

```js
async function matchingTokens(env, categories) {
  const catSet = new Set(categories || []);
  const tokens = [];
  let cursor;
  do {
    const page = await env.ARTICLES_KV.list({ prefix: 'sub:', cursor });
    for (const { name } of page.keys) {
      const row = await env.ARTICLES_KV.get(name, 'json');   // ← one GET per subscriber
      if (!row || typeof row.token !== 'string') continue;
      if (!rowMatchesCategories(row, catSet)) continue;
      tokens.push(row.token);
    }
    cursor = page.cursor;
  } while (cursor);
  return tokens;
}
```

**Description.**

Every cron cycle that finds new articles lists the entire `sub:` key-space and issues **one KV `get`
per subscription**, serially, to evaluate the category filter.

**Evidence.** The key-space map below is exhaustive for the single `ARTICLES_KV` namespace. `sub:` is
the one that scales with *users*; the others scale with content or are bounded:

| Key prefix | Grows with | TTL | Growth driver |
|---|---|---|---|
| `articles:v1` | rewritten each cycle | 10 min | bounded |
| `seen-ids:v1` | every article id seen | 24 h | bounded by TTL |
| `announced:<id>` | one key **per article** announced | 24 h | bounded by TTL |
| `sub:<token>` | one key **per subscribed device** | 90 d | **unbounded — M-2 inflates it** |
| `rl:<key>:<win>` | rate-limit counters | 2 × window | bounded |
| `config:sources` | admin override | none | bounded |
| `refresh:lock` | thundering-herd guard | 60 s | bounded |
| `fcm:access-token` | cached OAuth token | 55 min | bounded |

Only `sub:` has a TTL long enough for accumulation to matter, and it is the one an attacker can
inflate.

**Root cause**

Subscriptions are stored one-row-per-device so that `POST /subscribe` is a cheap upsert. That is a
reasonable write-side choice, but it makes the *read* side O(n) round-trips.

**Impact**

Two compounding costs. Legitimately, the cron cost grows with subscriber count — fine at hundreds,
degrading at thousands. Unhelpfully, **M-2 lets an attacker inflate `sub:` at will** (the
rate-limit key includes the caller-supplied token, and the gating secret ships in the APK). An
attacker who registers N fake tokens multiplies every subsequent cron cycle's KV read cost by N. The
`announced:<id>` key-space has the same shape: one key per article, written serially.

**Implementation**

Cheapest meaningful improvement — bound the work and skip the per-row read when possible:

```js
// Cap the scan. Beyond this the cron is doing more work than the feature is
// worth; subscribers past the cap get pushes on the next cycle's leading slice.
const MAX_SCAN = 2000;
...
for (const { name } of page.keys) {
  if (tokens.length >= MAX_SCAN) break;
  const row = await env.ARTICLES_KV.get(name, 'json');
  // ...
}
```

The structural fix is a separate subscriber *index* document (a single `subs:index` doc holding
`{token → categories}`) that `matchingTokens` reads in one `get`, with the per-token rows retained
only as the source of truth for the token itself. That converts O(n) reads into O(1) plus one write
per subscription.

**Verification**

Worker test with a stubbed KV holding N subscriptions: assert `matchingTokens` issues a bounded
number of `get` calls as N grows. Add a regression test for the M-2 fix alongside it — if the
rate-limit key changes, this should also stop being exploitable.

**Regression risk** A hard cap means the tail of a very large subscriber list receives delayed or
missed pushes. Given `announceNewArticles` already slices to 500 tokens
(`feed-worker.js:672`), subscribers beyond 500 already receive nothing in a given cycle — so a scan
cap introduces no new user-visible loss.

---

### [LOW] P-5 · `announceNewArticles` Does Serial GET+PUT Per Article

| | |
|---|---|
| **Endpoint / Method / Component** | Internal (cron `scheduled` handler) · n/a · `announceNewArticles` |
| **Affected Component** | `announceNewArticles` dedupe loop |
| **Confidence** | source-level |

**Evidence.** The loop body, `feed-worker.js:642-649` — two awaited KV operations per article, no
batching, no concurrency:

```js
const fresh = [];
for (const a of articles) {
  const k = 'announced:' + a.id;
  if ((await env.ARTICLES_KV.get(k)) !== null) continue;   // serial read
  await env.ARTICLES_KV.put(k, '1', { expirationTtl: 24 * 60 * 60 });  // serial write
  fresh.push(a);
}
```

The only caller today passes `articles.slice(0, 3)` (`feed-worker.js:405`), bounding it to three
round-trips — but the function accepts any slice length and its cost is linear in that.

**Description.** The dedupe loop awaits a `get` then a `put` for each article, strictly serially. The
surrounding comment is accurate about *why* the keys exist — "KV has no compare-and-swap, so two
concurrent refreshes can both reach this step" — so this is a correctness workaround, not an
oversight.

**Root cause** Awaited KV operations inside a loop, with no batching API available on KV to exploit.

**Impact** Bounded and small today (≤3 round-trips per cycle). It matters as a scaling note and
because the same key-space is what P-4's attacker inflates.

**Implementation**

```js
// Parallelise the dedupe reads; keep the writes serial so the
// first-writer-wins semantics of the marker key are preserved.
const probes = await Promise.all(
  articles.map((a) => env.ARTICLES_KV.get('announced:' + a.id)),
);
const fresh = [];
for (let i = 0; i < articles.length; i++) {
  if (probes[i] !== null) continue;
  await env.ARTICLES_KV.put('announced:' + articles[i].id, '1',
                            { expirationTtl: 24 * 60 * 60 });
  fresh.push(articles[i]);
}
```

With a bounded `articles.slice(0, N)` this is a micro-optimisation. If the slice ever grows, it
becomes a real latency win.

**Verification** Worker test asserting the same set of `fresh` ids is produced for a given KV state,
regardless of interleaving.

**Regression risk** Parallel reads are safe (KV reads are idempotent). The writes stay serial
precisely because the marker key's correctness *depends* on serialising them — do not "optimise"
those into a `Promise.all` too, or duplicate pushes become possible.

---

### [LOW] P-6 · No Cache-Control, ETag, or Last-Modified on Any Response

| | |
|---|---|
| **Endpoint** | All worker routes |
| **Affected Component** | `cors()` response wrapper |
| **Confidence** | **live-measured** |

**Source location** — `workers/feed-worker.js:920-927`. Same `cors()` helper as L-2.

**Evidence — complete header list on `GET /sources`:**

```
date, content-type, content-length, access-control-allow-origin,
access-control-allow-headers, access-control-allow-methods,
report-to, nel, server, cf-ray, alt-svc
```

Absent: `cache-control`, `etag`, `last-modified`, `expires`, `age`.

**Conditional-request probe:**

```
GET /sources  If-None-Match: "anything"
→ 200, no ETag in response
```

The server has no ETag to compare against, so the request cannot be answered `304`.

**Description.** Neither Cloudflare's edge cache nor the Dart HTTP client can revalidate. Every
`GET /sources` — which the app calls on **every cold start**
(`rss_feed_service.dart:179-209`, invoked unawaited from
`splash_screen.dart:106`) — transfers the full body.

**Root cause** Only CORS headers were ever added to the shared response wrapper. Same root as L-2.

**Impact**

Low on its own: `/sources` is 1,668 bytes and gzips to a fraction of that. Worth fixing because it
is two lines in a function that is already being touched for L-2, and because `ETag` on
`/articles` would let a returning client skip a 72 KB body entirely on an unchanged feed.

**Implementation**

```js
// workers/feed-worker.js:920-927
function cors(response, { etag } = {}) {
  const r = new Response(response.body, response);
  r.headers.set('Access-Control-Allow-Origin', CORS_ALLOWED_ORIGIN);
  r.headers.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
  r.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-api-secret');
  // L-2 hardening
  r.headers.set('X-Content-Type-Options', 'nosniff');
  r.headers.set('Referrer-Policy', 'no-referrer');
  r.headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  // P-6: let clients and the edge revalidate instead of re-downloading.
  r.headers.set('Cache-Control', 'public, max-age=60');
  if (etag) r.headers.set('ETag', etag);
  return r;
}
```

For `/articles`, derive the ETag from the cache key's content hash and honour `If-None-Match`
before doing the filter+sort work (which is where P-3's cost lives):

```js
// in handleArticles, before applyFilters/sort
const tag = `"${await env.ARTICLES_KV.get('articles:v1:etag')}"`;
if (request.headers.get('If-None-Match') === tag) {
  return new Response(null, { status: 304, headers: { ETag: tag } });
}
```

**Verification** Request `/sources` twice with `If-None-Match` and confirm `304`. Confirm the
`Cache-Control` value does not break the app's own refresh logic — the Dart client does not cache, so
this affects only Burp/curl and any future HTTP-cache-aware client, which makes it a safe,
low-risk change.

**Regression risk** Very low. Dart's `http.Client` performs no HTTP caching, so no app behaviour
changes. Do **not** add a long `max-age` to authenticated routes (`/subscribe`, `/articles/refresh`)
— a shared cache replaying those would be a real bug. Keep the `max-age=60` scoped to
`/articles` and `/sources`.

---

### [LOW] P-7 · Client Hot Paths With Plausible Battery Cost — UNQUANTIFIED

| | |
|---|---|
| **Endpoint / Method / Component** | n/a — client-side, no HTTP surface · n/a · see table below |
| **Affected Component** | Client — `ClientFeedService`, `ArticleContentService`, `FeedDatabase`, `FeedScreen` |
| **Confidence** | **unmeasured** — no `adb`/emulator/Android SDK on the audit host |

**Description.** These were identified by reading the client and tracing call paths. **None were
measured.** They are listed as findings rather than omitted, because their absence from a report
would imply they had been checked and found clean — which would be false.

**Evidence** — locations and the reason each may cost. No timing data exists for any of these:

| Suspect | Location | Why it may cost |
|---|---|---|
| `Isolate.run` for every feed parse | `client_feed_service.dart:94` | Spawns an isolate per custom source per refresh. Isolate creation is not free; with many custom feeds this is per-source overhead. |
| `Isolate.run` for article content | `article_content_service.dart:65` | Spawns an isolate to parse one article's HTML. For a single article the spawn cost may exceed the parse saving. |
| Full-table rewrite per refresh | `feed_database.dart:145-157` | `saveArticles` does `DELETE` + batch reinsert of up to 1000 rows on **every** refresh, even when 1 article changed. |
| Row-per-save position shift | `feed_database.dart:230` | `UPDATE saved_articles SET position = position + 1` is O(n) on every new save. |
| GitHub check on every cold start | `feed_screen.dart:130` | Third-party round-trip per launch (see P-2). |
| Refresh on connectivity regain | `feed_screen.dart:266-268` | Any offline→online transition with a non-empty feed triggers a refresh. Flapping connectivity = repeated refreshes. |
| Auto-refresh timer re-armed on resume | `feed_screen.dart:149` | Every resume arms a fresh timer, so a user toggling between apps accrues refreshes. |

**Root cause** Unknown without measurement. Each may be a deliberate, documented trade-off — several
carry comments explaining the reasoning (e.g. the `Isolate.run` comments cite measured CPU savings on
mid-range phones). The point of listing them is to prioritise what to profile, not to assert they are
defects.

**Impact** Unknown. Not scored.

**How to actually measure** — the toolchain this host does not have:

```bash
# 1. Frame timing / jank
flutter run --profile
#    DevTools → Performance, or:
flutter run --profile --trace-skia

# 2. Battery attribution
adb shell dumpsys batterystats --reset
#    ...exercise the app for N minutes...
adb shell dumpsys batterystats > after.txt
#    Look for com.curatedfeeds in the wakeup/CPU sections.

# 3. Isolate churn
#    DevTools → Performance → track isolate spawn events; or:
adb logcat | grep -i "isolate"

# 4. Network cost per session
adb shell dumpsys netstats detail
```

**Recommendation.** Profile before changing any of these. The `saveArticles` full-rewrite is the one
most likely to matter (it runs on every refresh and touches up to 1000 rows), and it has an obvious
cheap alternative — diff against the existing row set and write only changed ids — but shipping
that without a measurement would be guessing.

**Implementation**

None proposed. Implementing a speculative fix here would mean optimising code whose cost has not
been established, against comments that cite measurements taken on different hardware.

**Verification**

Requires a device. The measurement commands are above; the acceptance criterion should be set only
after a baseline is captured, not before.

**Regression risk**

n/a — no change proposed.

---

### 12.2 Disproved Hypothesis (recorded so it is not re-investigated)

| Hypothesis | Verdict | Evidence |
|---|---|---|
| The worker does not compress responses | **FALSE** | Burp reported `content-encoding=ABSENT` because it transparently decodes. `curl` with `Accept-Encoding: gzip` returns `content-encoding: gzip`. Measured on `pageSize=100`: **identity 127,191 bytes → gzip 28,792 bytes (4.4×)**. Compression is working correctly and is not a finding. |

Recorded because the Burp-observed header set is genuinely misleading on this point, and the next
person to probe will see the same thing.

---

## 13. Revenue & Growth Findings (Pass 4)

Pass 4 re-audited against a different objective: **earn revenue and grow the user base.** The first
three passes optimised for security severity and would have ranked these findings last, several of
them not at all.

### 13.0 Why these were absent from passes 1–3

**R-1 is not a bug.** A SnackBar explaining that the free limit was reached is *correct behaviour* by
every conventional standard — it informs the user, respects the limit, and does not interrupt. It
only becomes a defect when the goal is conversion, because it names the product ("Go Pro for
unlimited saves") and then routes nowhere.

R-2 and R-4 are policy and platform features that no vulnerability scanner flags, because neither is
a defect in the code — they are absences of code.

This is a limitation worth stating plainly: **an audit optimised for security does not find revenue
leaks.** The three previous passes produced a good security report and would have shipped an app
whose paywall never triggers.

### 13.1 Finding Index (pass 4)

| ID | Severity | Finding | Confidence |
|---|---|---|---|
| **R-1** | Medium | Cap-hit shows a SnackBar and never routes to the paywall | source-level |
| **R-2** | Medium | No account deletion flow — Play submission blocker | source-level |
| **R-3** | Medium | Zero paywall or purchase analytics — funnel is unmeasurable | source-level |
| **R-4** | Medium | No in-app review prompt | source-level |
| **R-5** | Low | 65.6 MB APK / 66 MB AAB across 3 ABIs, no splits | source-level |
| **R-6** | Low | No fastlane, store metadata, or listing copy in repo | source-level |

---

### [MEDIUM] R-1 · Cap-Hit Shows a SnackBar and Never Routes to the Paywall

| | |
|---|---|
| **Endpoint / Method / Component** | n/a (local UI) · n/a · `FeedScreen._onSwipeRight` + `_onToggleSave` |
| **Affected Component** | The entire monetisation funnel |
| **Confidence** | source-level |
| **Impact class** | **Revenue loss — highest-value single fix in this report** |

**Source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/screens/feed_screen.dart` | 436–448 | swipe-to-save cap hit → SnackBar, `return` |
| `lib/screens/feed_screen.dart` | 505–513 | save-button cap hit → SnackBar, `return` |
| `lib/screens/settings_screen.dart` | 534 | the **only** `PaywallScreen()` construction in the codebase |
| `lib/utils/constants.dart` | 96 | `freeSavedArticlesCap` = 5 (Play) / 25 (direct) |
| `lib/utils/reader_theme.dart` | 102–103 | `isReaderThemeLocked` — the second Pro surface |

**Description**

There are exactly two places where a free user hits the paywall wall. Both show a SnackBar and
return. Neither routes to `PaywallScreen`.

```dart
// lib/screens/feed_screen.dart:436-448  (swipe-to-save)
if (!isPro &&
    !isAlreadySaved &&
    _savedArticles.length >= AppConfig.freeSavedArticlesCap) {
  final now = DateTime.now();
  if (_lastCapHintAt == null ||
      now.difference(_lastCapHintAt!) > const Duration(minutes: 5)) {
    _lastCapHintAt = now;
    _showSnackBar(
      _l10n.freeSavedLimitReached(AppConfig.freeSavedArticlesCap),
    );
  }
  return;                                    // ← no navigation
}
```

```dart
// lib/screens/feed_screen.dart:505-513  (save button)
final isSaving = !article.isSaved;
if (isSaving) {
  final isPro = context.read<SettingsNotifier>().isPro;
  if (!isPro && _savedArticles.length >= AppConfig.freeSavedArticlesCap) {
    _showSnackBar(
      _l10n.freeSavedLimitReached(AppConfig.freeSavedArticlesCap),
    );
    return;                                  // ← no navigation
  }
}
```

Meanwhile the paywall has exactly one construction site:

```dart
// lib/screens/settings_screen.dart:526-537
_buildActionTile(
  icon: Icons.workspace_premium_outlined,
  title: isPro ? _l10n.proBadge : _l10n.supportAppTitle,
  subtitle: isPro ? _l10n.thanksSupportSubtitle : _l10n.supportOneTimeSubtitle,
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
  },
),
```

**Evidence** — exhaustive search:

```
$ grep -rn "PaywallScreen()" lib/
lib/screens/settings_screen.dart:534   ← only hit

$ grep -rn "PaywallScreen" lib/screens/*.dart lib/widgets/*.dart
lib/screens/settings_screen.dart:23   (import)
lib/screens/settings_screen.dart:534  (construction)
```

The SnackBar copy, from `lib/l10n/app_en.arb:91`:

> "Free limit of {count} saved articles reached — **Go Pro for unlimited saves**"

The message names the product and gives the reason to want it, then offers no way to act on it.

**Root cause**

The cap was implemented as a *guard* (prevent the write, tell the user why) rather than as an
*upsell moment*. The paywall was wired to Settings — a place a free user has no reason to visit
until they have already hit the wall elsewhere — and no connection was made between the two.

**Impact**

Every free user who reaches the cap is offered a purchase in a dismissible transient banner and
given no path to complete it. The funnel is:

```
hit cap  →  SnackBar names Pro  →  user must independently find Settings → Support the app
```

Only a user who already suspects the app has a paid tier will complete that path. No funnel data
exists (R-3) to quantify the loss, but the structural conclusion does not depend on measurement: an
upsell that does not link to the purchase screen is not an upsell.

This is compounded by the second Pro surface. `isReaderThemeLocked` (`reader_theme.dart:102-103`)
locks sepia and e-ink behind the same flag, and `reader_controls.dart:97` handles a locked swatch
by calling `onLocked`, which in `expanded_article_card.dart:607-618` shows *another* SnackBar
(`proThemeLocked`) — also with no navigation.

**Implementation**

Option A — route directly to the paywall. Recommended for a first attempt because it is measurable
and easy to soften later:

```dart
// lib/screens/feed_screen.dart — extract once, use at both sites
void _promptUpgrade() {
  unawaited(AnalyticsService.logPaywallShown(
    trigger: _lastCapHintTrigger,
    savedCount: _savedArticles.length,
  ));
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
  );
}
```

```dart
// :443 — swipe-to-save cap hit
if (_lastCapHintAt == null ||
    now.difference(_lastCapHintAt!) > const Duration(minutes: 5)) {
  _lastCapHintAt = now;
  _promptUpgrade();
}
return;

// :508 — save-button cap hit
if (!isPro && _savedArticles.length >= AppConfig.freeSavedArticlesCap) {
  _promptUpgrade();
  return;
}
```

Apply the same to the locked-theme handler in `expanded_article_card.dart:607-618`.

Option B — a lighter upsell sheet first ("Unlock unlimited saves · See what Pro includes"), routing
to the full paywall on a second tap. Gentler, and usually nets more revenue long-run because a hard
wall on save is a strong source of uninstall.

**Recommendation:** Option A first, instrument via R-3, then decide. Do not attempt both at once —
you cannot attribute a conversion change to a design you changed and a funnel you just built in the
same release.

**Verification**

Widget test: set the saved count to `AppConfig.freeSavedArticlesCap`, tap save, assert
`find.byType(PaywallScreen)` is present. Requires registering `InAppPurchasePlatform` — the fake
pattern already exists at `test/unit/screens/paywall_screen_test.dart:20-50`.

**Regression risk**

Low, with one honest caveat: it converts a **non-blocking** prompt into a **blocking** one. Users who
were previously satisfied by the SnackBar now face a full screen. If uninstall rate rises rather
than conversion, switch to Option B — that is exactly what R-3's instrumentation is for. Also note
the 5-minute hint throttle at `:439-446` should be retained, or a user swiping rapidly would get a
navigation push per gesture.

---

### [MEDIUM] R-2 · No Account Deletion Flow — Play Submission Blocker

| | |
|---|---|
| **Endpoint / Method / Component** | n/a · n/a · `SettingsScreen` account section |
| **Affected Component** | Play Store distribution |
| **Confidence** | source-level |
| **Impact class** | **Blocks distribution entirely** |

**Source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/screens/settings_screen.dart` | 1287 | the only account action: `getIt<AuthService>().signOut()` |
| `lib/services/auth_service.dart` | 67–77 | `signOut` — clears sessions, deletes nothing |
| `docs/play-store-release.md` | 47 | *"Account deletion: users can delete their Firestore tenant data via account removal — verify flow before submission"* |

**Description**

The app creates accounts (Firebase Auth, Google + email/password) but provides no way to delete
them. Settings offers sign-out only, and `signOut` removes the local session — it does not touch
`users/{uid}/**` in Firestore or the Firebase Auth record.

**Evidence** — exhaustive search, all zero hits:

```
$ grep -rn "deleteAccount"      lib/ android/   → 0
$ grep -rn "deleteUser"         lib/ android/   → 0
$ grep -rn "accountDeletion"    lib/ android/   → 0
$ grep -rn "account_deletion"   lib/ android/   → 0
$ grep -rn "Delete account"     lib/ android/   → 0
```

The only account action anywhere:

```dart
// lib/screens/settings_screen.dart:1286-1288
if (confirmed == true) {
  await getIt<AuthService>().signOut();
}
```

Google Play requires that any app enabling account creation also provides an in-app path to request
account deletion. The app has not shipped to Play yet, so this has not blocked anything — but it
blocks the first upload and every update thereafter.

Note the gap between the docs and the code: `play-store-release.md:47` asserts users *can* delete
their Firestore data "via account removal", which reads as though it is handled. It is not.

**Root cause**

Account deletion was listed as a manual Play Console checklist item and never implemented, on the
assumption that `FirebaseAuth.deleteUser()` plus a Firestore delete would be trivial to add later.

**Impact**

- **Blocks Play submission.** Every upload and every update is gated on this.
- **GDPR/retention exposure.** Deleting the Firebase Auth record without deleting `users/{uid}/**`
  leaves orphaned personal data (email, display name, reading history) indefinitely, with no
  retention path and no user-facing control.
- Affects the direct/GitHub channel equally from a privacy standpoint, even though Play is the
  only place it is enforced.

**Implementation**

```dart
// lib/services/auth_service.dart — add alongside signOut
Future<void> deleteAccount() async {
  final user = _auth.currentUser;
  if (user == null) return;

  // 1. Remove the cloud mirror FIRST. If deleteUser() succeeds and the
  //    Firestore wipe fails, the Auth record is gone and we can no longer
  //    prove ownership of the data — leaving it orphaned with no path back.
  final sync = getIt.isRegistered<CloudSyncService>()
      ? getIt<CloudSyncService>()
      : null;
  await sync?.purgeUserData(user.uid);

  // 2. Then the auth record.
  await user.delete();
}
```

```dart
// lib/services/cloud_sync_service.dart — new method
/// Deletes every document under `users/{uid}`. Firestore does not cascade
/// deletes, so each collection must be cleared explicitly.
Future<void> purgeUserData(String uid) async {
  final root = _firestore.collection('users').doc(uid);
  // Recursive delete handles every subcollection in one round trip and is
  // the only approach that stays correct if a new subcollection is added.
  await root.delete();
}
```

The Firestore recursive-delete form is `db.recursiveDelete(docRef)`, available in the Firebase
Admin SDK and — check your client SDK version — via a Cloud Function. **Verify which is available in
your `cloud_firestore` version before implementing**; if client-side recursive delete is unavailable,
enumerate the known subcollections (`articles`, `settings/main`, `sources/main`, `sync_state/main`)
and delete each, plus a root field update, accepting that a future subcollection would need adding.

Then wire it into Settings next to sign-out, behind a typed confirmation (Play expects a deliberate
gesture) and a clear statement of what is deleted.

**Verification**

Manual, against a throwaway account: create an account, save articles, delete the account, then
confirm via the Firebase console that no `users/{uid}` documents remain. This cannot be unit-tested
without the emulator.

**Regression risk**

Irreversible by design — that is the requirement. The main risk is ordering: if `deleteUser()`
succeeds and the Firestore wipe then fails, the data is orphaned with no way to prove ownership and
recover. Hence the deliberate ordering above.

---

### [MEDIUM] R-3 · Zero Paywall or Purchase Analytics — Funnel Is Unmeasurable

| | |
|---|---|
| **Endpoint / Method / Component** | n/a · n/a · `AnalyticsService` + `PaywallScreen` |
| **Affected Component** | Every future monetisation decision |
| **Confidence** | source-level |

**Source locations**

| File | Line(s) | Role |
|---|---|---|
| `lib/services/analytics_service.dart` | 21–67 | 16 event methods — none paywall or purchase related |
| `lib/screens/paywall_screen.dart` | whole file | fires **zero** analytics calls |

**Description**

`AnalyticsService` has no monetisation events, and `PaywallScreen` fires no analytics of any kind.
The funnel is unmeasurable at every step: no view of the paywall, no record of a purchase attempt,
and no signal at the moment the user hits the limit.

**Evidence** — the complete event catalogue in `analytics_service.dart:21-67`, reproduced:

```
app_open · app_start · feed_refresh · feed_load · filter_change
article_open · article_share · article_link_open · article_save
article_read_complete · search · session_start · session_end · error
```

Sixteen events, none paywall or purchase related. And the paywall itself:

```
$ grep -n "AnalyticsService\|PostHog" lib/screens/paywall_screen.dart
(no matches)
```

`PaywallScreen` fires **zero** analytics, despite importing `provider` and already having a
`SettingsNotifier` to read from (`paywall_screen.dart:171`).

**Root cause**

`AnalyticsService` was built to answer "how do people use the feed?" and does so competently — the
fan-out wrapper at `:15-18` is clean. Nobody added the second question: "do they pay, and where do
they drop off?" The naming (`logArticleOpen`, `logFeedRefresh`) signals usage intent throughout.

**Impact**

The funnel cannot be measured at any step. Concretely, after implementing R-1 you will not know
whether it converted, whether the SnackBar variant or the full-paywall variant performs better, or
whether the locked-theme prompt is worth keeping. You would be optimising a revenue path blind.

This is ranked **above** R-4 and the security findings deliberately: instrumentation before
optimisation is the only way R-1's outcome can be evaluated rather than guessed at.

**Implementation**

```dart
// lib/services/analytics_service.dart — add to the catalogue
static Future<void> logPaywallShown({
  required String trigger,     // 'save_cap' | 'theme_lock' | 'settings'
  required int savedCount,
  required int cap,
}) => _log('paywall_shown', {
  'trigger': trigger, 'saved_count': savedCount, 'cap': cap,
});

static Future<void> logPaywallAction({
  required String action,      // 'buy' | 'restore' | 'dismiss'
  required String trigger,
}) => _log('paywall_action', {'action': action, 'trigger': trigger});

static Future<void> logPurchaseCompleted({
  required String productId,
}) => _log('purchase_completed', {'product_id': productId});

static Future<void> logCapHit({ required int savedCount }) =>
  _log('cap_hit', {'saved_count': savedCount});
```

Then call `logCapHit` at both cap sites (`feed_screen.dart:443, 508`) and the three paywall hooks in
`PaywallScreen` (`_loadStore` success, `_onPurchaseUpdated`, and the dismiss path).

The `trigger` parameter is what makes A/B comparison of R-1's two variants possible later — without
it you would be comparing two designs and unable to attribute the result.

**Verification**

`flutter test` on the event-name mapping; then confirm events arrive in Firebase Analytics DebugView
on a debug build.

**Regression risk**

None functionally. Two operational cautions: (a) `logArticleOpen` already sends raw article titles
(`analytics_service.dart:38-41`), so do not add article *content* to purchase events — titles in
analytics plus the Data Safety form in `play-store-release.md:42` is a disclosure surface; (b) each
event costs quota, so keep the set small.

---

### [MEDIUM] R-4 · No In-App Review Prompt

| | |
|---|---|
| **Endpoint / Method / Component** | n/a · n/a · app-wide |
| **Affected Component** | Play Store ranking signal |
| **Confidence** | source-level |

**Description**

There is no path from a satisfied user to leaving a review. `in_app_review` is not a dependency:

```
$ grep -n "in_app_review" pubspec.yaml
(no match)
```

**Evidence**

```
$ grep -rn "in_app_review\|InAppReview\|requestReview" pubspec.yaml lib/
(no matches)
```

No review API is called anywhere in `lib/`. Store ratings are a ranking input, and the standard Play
mechanism for converting an engaged user into a rating — the in-app prompt — is absent.

**Root cause**

Growth features were not part of any prior pass's scope. The app was built and hardened as a reader;
nothing in the pipeline evaluates whether it is *discoverable* or whether happy users are converted
into ratings.

**Impact**

Passive rating accumulation only. Engaged users who never visit the store listing never rate. For
an app whose growth depends on organic ranking, this is the cheapest available lever going unused.

**Implementation**

```yaml
# pubspec.yaml
dependencies:
  in_app_review: ^2.0.10
```

The package is first-party (Google), ~0 transitive weight, and is the standard mechanism.

```dart
// lib/services/analytics_service.dart
static Future<void> maybeRequestReview() async {
  final review = InAppReview.instance;
  if (await review.isAvailable()) {
    await review.requestReview();
  }
}
```

Call it **once**, at a genuine satisfaction signal — not on launch and not on a timer. The strongest
available signal in this app is a completed article read:

```dart
// expanded_article_card.dart — on reader close
if (!context.read<SettingsNotifier>().isPro) {   // never nag payers
  unawaited(AnalyticsService.maybeRequestReview());
}
```

Google's guidance is to ask at most a few times per year; `InAppReview` does not enforce a limit, so
that discipline has to be yours. Guard it behind a local timestamp.

**Verification**

Manual on a physical device — the prompt is suppressed by Google on emulators and in some regions,
so a Play Internal-track build is the only reliable check.

**Regression risk**

The real risk is **annoyance**, not breakage: a prompt shown too often drives uninstalls. Gate it on a
saved "last asked" timestamp (30–90 days) and never show it immediately after a purchase or a
dismissed dialog. Do not put it on a screen the user is trying to leave.

---

### [LOW] R-5 · 65.6 MB APK / 66 MB AAB Across 3 ABIs

| | |
|---|---|
| **Endpoint / Method / Component** | n/a (build artifact) · n/a · Gradle ABI configuration |
| **Affected Component** | Distribution size |
| **Confidence** | source-level (measured from built artifacts) |

**Evidence**

```
outputs/flutter-apk/app-direct-release.apk        65.6 MB
outputs/bundle/playRelease/app-play-release.aab   66.0 MB
outputs/bundle/directRelease/app-direct-release.aab 66.1 MB
```

Largest native payloads: `lib/x86_64/libflutter.so` 12.45 MB, `lib/arm64-v8a/libflutter.so` 11.20 MB,
`lib/armeabi-v7a/libapp.so` 9.47 MB, `lib/x86_64/libapp.so` 8.75 MB,
`lib/arm64-v8a/libapp.so` 8.50 MB, `lib/armeabi-v7a/libflutter.so` 8.22 MB.

`android/app/build.gradle.kts` declares **no** `abiFilters`, no `splits`, and no `ndk` block — so
every ABI is compiled into every artifact.

**Description**

Three ABIs are shipped where two (or one, via an App Bundle) would do. `x86_64` is emulator-only
and has no place in a Play-delivered artifact at all — Play splits by ABI and would never install
the x86_64 slice on a physical device.

**Impact**

- **Play download size** is per-device (AAB), so the real user cost is roughly the arm64-v8a slice
  (~20 MB of Flutter runtime + app), not 66 MB. This is therefore **not** a Play upload blocker and
  not as bad as the raw number suggests.
- **Sideload/GitHub APK** genuinely is 65.6 MB for every user, x86_64 included. On the direct
  channel — the one carrying the free 25-article tier — this is real install friction.
- No immediate action needed for Play. Action is cheap and worthwhile for the sideload channel.

**Root cause**

`abiFilters` was never set. This is the default behaviour when ABI filtering is not requested
explicitly, so it is an omission rather than a decision — nothing in the codebase or docs suggests
the three-ABI artifact was ever considered.

**Implementation**

Play's per-device delivery already solves this; declare it explicitly rather than by omission:

```kotlin
// android/app/build.gradle.kts
android {
  defaultConfig {
    ndk {
      // x86_64 is emulator-only. Play never installs it on a device, and
      // shipping it adds ~21 MB to every sideload APK.
      abiFilters += listOf("arm64-v8a", "armeabi-v7a")
    }
  }
}
```

Dropping x86_64 alone removes ~21 MB from the APK and ~21 MB from the AAB upload. Removing
`armeabi-v7a` as well (if you no longer support pre-2017 devices) saves another ~18 MB.

**Verification** Rebuild and compare `ls -la` on the output; confirm Play still serves arm64 and
armv7 devices.

**Regression risk** Loses x86_64 emulator testing. Keep the filter in a `debug`-only block or
document that emulator runs need `--target-platform android-arm64` (Apple-silicon hosts) or a
physical device.

---

### [LOW] R-6 · No Fastlane, Store Metadata, or Listing Copy in Repo

| | |
|---|---|
| **Endpoint / Method / Component** | n/a (release process) · n/a · repository tooling |
| **Affected Component** | Release process |
| **Confidence** | source-level |

**Description**

Every Play Console step — listing copy, screenshots, Data Safety form, content rating — is manual and
lives only in the Console UI. The only in-repo documentation is `docs/play-store-release.md`, which
is a checklist rather than a source of truth.

**Evidence**

```
$ ls fastlane metadata store-listing
absent:  fastlane
absent:  metadata
absent:  store-listing
```

No `fastlane/Fastfile`, no `Supplyfile`, no per-locale listing text. The app ships `en` and `hi`
(`lib/l10n/app_en.arb`, `app_hi.arb`) but there is no `hi` store listing anywhere in the repo.

**Root cause**

Solo-operator workflow. Each Play step has been performed once through the Console UI, which works
until the second release — at which point "what did we change in the listing?" has no answer in
version control.

**Impact**

Not a defect; an operational risk. Listing copy cannot be reviewed in a PR, cannot be translated
consistently (the app ships `en` and `hi`, but there is no `hi` listing), and changes have no audit
trail. For a solo operator, this is the most common source of "the store page says X and the app
says Y".

**Implementation**

Adopt fastlane's supply structure so listing text is version-controlled:

```
fastlane/metadata/android/en-US/
  title.txt              short_description.txt   full_description.txt
  changelogs/  images/  video/
fastlane/Fastfile        # upload flow
fastlane/Supplyfile
```

This also lets R-5's per-device size and the store listing's accuracy be checked in CI rather than
by eye.

**Verification** `bundle exec fastlane supply --validate` in CI.

**Regression risk** None. Purely additive tooling.

---

## 14. Files Touched by This Audit

**Modified:** none. `git status --porcelain` shows only `?? burp-audite.md` — untracked, never
staged, never committed. All four passes were read-only.

**Read (not modified):** all 63 files under `lib/`, `workers/feed-worker.js`,
`workers/test/feed-worker.test.js`, `workers/wrangler.toml`, `firestore.rules`, `firebase.json`,
`shorebird.yaml`, `.circleci/config.yml`, all five `android/app/src/*/AndroidManifest.xml`,
`android/app/build.gradle.kts`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`,
`CHANGELOG.md`, `README.md`, and `docs/`.

**Created:** this report (`burp-audite.md`).

**Pass-4 method.** Static source review only — no device, emulator, Play Console, or billing
sandbox was available, so nothing in §13 was exercised end to end. Specifically **unverified**:
whether the Play Console has `cf_pro_lifetime` configured and live; whether account deletion is
actually enforced for this app today; and whether the current Play policy wording matches the
premise behind R-2. Each of those needs a check against the live Console before acting on it.
No HTTP requests were made in pass 4 beyond one read-only `curl -I` against the GitHub releases
endpoint to confirm I-7.

**Pass-3 probes.** All read-only HTTP GETs against `curated-feeds-worker.raj15400881.workers.dev`
and `api.github.com`, plus `curl` for byte-accurate measurements (Burp truncates large bodies).
Timing benchmarks: 20–25 sequential requests per endpoint, run after a warm-up request, averaged.
No state-changing request was made in pass 3 — no `POST`, `PUT`, or `DELETE`, so no production data
was created or modified.

**Pass-2 probe file:** `test/unit/services/zz_audit_probe_test.dart` was created to instrument the
SQLite layer, run, and **deleted**. It is not in the repository and does not appear in the test
count. It is named here so the reproduction steps in [§9.2](#92-probe-results-verbatim) are
followable if someone wants to rebuild it.

**Test artifacts:** `pubspec.lock` was transiently modified by `flutter pub get` resolving
transitive dependency metadata during the first `flutter analyze`. It was reverted with
`git checkout pubspec.lock`; the working tree is clean.

**Production state:** one probe token (`audit-probe-token-0001`) was submitted to `POST /subscribe`
and immediately removed via `DELETE /subscribe`. Both returned `401` (stale secret), so no row was
ever created. No production data was created, modified, or deleted. The extracted secret was staged
briefly in a `0600` temp file outside the repository and deleted; **its value is redacted
throughout this report.**

**Git history:** read-only inspection via `git log`, `git grep`, and `git rev-list --all`. No
history rewriting, no branch operations.