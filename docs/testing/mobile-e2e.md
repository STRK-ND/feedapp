# Android device end-to-end tests

The Curated Feeds app is verified on a real Android device or emulator by the
[e2e](https://e2e.tester.army) mobile engine (`@e2e-dev/mobile`, built on
`agent-device`). The suite lives in [`e2e/`](../../e2e/) with its own
`package.json`, so the Flutter project at the repository root keeps a single
toolchain and no Node dependencies.

## Prerequisites

The engine drives the device over `adb`, so nothing runs without the Android
SDK:

```bash
# 1. Android SDK on the machine, with adb on PATH
export ANDROID_HOME=~/Android/Sdk
export PATH="$PATH:$ANDROID_HOME/platform-tools"

# 2. An emulator or a phone with USB debugging
adb devices

# 3. A build to install (no --flavor play: the store handles updates there,
#    so the feed hides its "Check for updates" menu item)
flutter build apk --debug

# 4. The engine's own preflight
cd e2e && npx agent-device doctor
```

`npx agent-device doctor` reports `device-android: ... adb not found in PATH`
until steps 1 and 2 are done. `e2e/e2e.config.ts` points at
`../build/app/outputs/flutter-apk/app-debug.apk`; set `CURATED_FEEDS_APK` to
run another build.

## Run it

```bash
cd e2e
bun install                      # or npm install
npx e2e list                     # every test and its line number
npx e2e run                      # the whole suite on the android target
npx e2e run tests/feed.e2e.ts:7   # one test, by the line its test( opens on
npx e2e run --tag network        # only the flows that need the network
npx e2e run --exclude-tag network
```

`npx e2e list` is the fastest way to see the current coverage without a
device: collection needs no emulator, only the config and the sources.

## How the locators work

Flutter exposes almost no `Semantics(identifier:)`, so `getByTestId` finds
little here. The suite reads the names the app already renders:

| What the app sets | Locator in the suite |
| --- | --- |
| `Semantics(button: true, label: <string>)` | `screen.getByRole('button', '<string>')` |
| `Text(<localized string>)` | `screen.getByText('<string>')` |
| `InputDecoration(hintText: <string>)` | `screen.getByPlaceholder('<string>')` |
| `SwitchListTile` / `Switch` | `screen.getByRole('switch', '<title>')` |
| `CurvedNavItem` (`Semantics(label: '<name> tab')`) | `screen.getByRole('button', /^<name> tab/)` |

The exact strings live in [`lib/l10n/app_en.arb`](../../lib/l10n/app_en.arb)
and are collected once in [`tests/support/app.ts`](../../e2e/tests/support/app.ts),
so a string change is one edit. Every text changes with the locale, so this
suite runs against English.

Two design points:

- **No app changes for tests.** No test id, agent-action or debug hook is added
  to `lib/`; the suite uses the names the shipped UI already has.
- **No model required.** Every step is deterministic, so the suite runs with no
  agent credentials. Flows that need the network are tagged `network` and
  excluded on an offline machine.

## What the suite covers

| File | Flows |
| --- | --- |
| `tests/onboarding.e2e.ts` | splash tagline, the three rooms with descriptions, reading tuning (font size, line height, typewriter datelines), source picking, and the bottom navigation |
| `tests/feed.e2e.ts` | app-bar actions, empty feed and its recovery hint, search with result and no-result counts, the saved tab, the update-check menu |
| `tests/sources.e2e.ts` | subscribed/discover split, custom feed URL validation, OPML export with nothing subscribed |
| `tests/settings.e2e.ts` | all nine sections, appearance toggles, notification switches, feed settings, reader typography, clear-cache confirmation, about rows, the account section |
| `tests/account.e2e.ts` | sign-in options, register toggle, malformed-email and weak-password validation, reset-password |
| `tests/paywall.e2e.ts` | the Pro paywall and its offer rows, store-unavailable handling |
| `tests/updates.e2e.ts` | "Check for updates" reporting the current version (`network`) |

## What it does not cover

- **Real purchase and account flows** need Play Store and Firebase accounts;
  they are asserted only up to the first server response (validation, the
  register toggle, the sheet's own copy).
- **Article triage** (swipe right to save, the folio rule, undo) needs a source
  that answers, so the flow that needs it is tagged `network`; an emulator with
  no feed loads the empty state instead.
- **Background sync and notifications** are `WorkManager` and OS behaviour;
  the unit and integration tests under [`test/`](../../test/) cover them, and
  the device suite drives only the Settings toggles.
- **The update dialog** (`docs/store-screenshots.md` is unrelated) appears only
  when the GitHub Releases API advertises a newer build, so it is not asserted
  on every run.

## The worker contract: e2e and curl

The Android app is a client of the Cloudflare worker in
[`workers/feed-worker.js`](../../workers/feed-worker.js). That contract is
verified twice, by two independent methods, and both run on this machine with
no emulator, no Cloudflare account and no network:

**With curl.** [`workers/dev-server.mjs`](../../workers/dev-server.mjs) serves
the *real* worker over local HTTP with an in-memory KV and a seeded feed, and
[`tool/api-contract.sh`](../../tool/api-contract.sh) curls every route, method
and error path against it:

```bash
tool/api-contract.sh            # 27 checks: routes, filters, auth, overrides
tool/api-contract.sh --quick    # public reads and routing only
```

**With e2e.** The `worker-api` target in `e2e.config.ts` is tools-only, so it
runs anywhere Node runs and asserts the same facts with `fetch`:

```bash
node workers/dev-server.mjs &   # or: cd workers && npm run dev
cd e2e && npx e2e run tests/worker-api.e2e.ts
```

Both suites pin the parts of the contract the app depends on: `503 busy` is
transient and retried, a 503 that is *not* busy is a server fault, the app
secret cannot rewrite the canonical source list, and an empty source list is
refused with `400`.

## Measuring and improving API latency

Two harnesses ship with the repo. Both run locally with no Cloudflare account:

```bash
# KV round-trips the worker performs per request (each get/put is one edge
# round trip a real deployment pays).
node tool/api-kv-ops.mjs

# A/B: the committed worker against the working tree, each KV op delayed by
# --kv-latency so the difference is measured rather than asserted. Reads the
# baseline from git HEAD, so it is reproducible on any checkout.
node tool/api-ab.mjs --kv-latency 5 --seed 269 --requests 40
```

### What the measurement found

Local CPU latency is dominated by Node's own HTTP round trip, and it is flat
regardless of the cache size (a cold first request costs ~65 ms at 1 article
and ~68 ms at 2000 — that is V8 compiling the worker's code path, not JSON
parsing, so there is no algorithmic win left in the read path).

The cost that mattered was **Cloudflare KV round-trips**, which local latency
cannot see: every read request did **two gets and one write**. The write was
the rate limiter's read-modify-write counter, maintained on every single
request.

### The change

`consumeRate` now counts per isolate in memory and flushes to KV once per
window per caller, so a repeated caller — exactly what the app does — costs
**one KV round trip instead of three**.

Measured with `tool/api-ab.mjs --kv-latency 5` (5 ms per KV op), 269 seeded
articles, 8 rotating clients:

| route | before p50 | after p50 | KV ops |
| --- | --- | --- | --- |
| `GET /articles` | 19.5 ms | 9.2 ms | 3 → 1 |
| `GET /articles?source=verge` | 18.8 ms | 7.0 ms | 3 → 1 |
| `GET /articles?q=…` | 19.6 ms | 8.0 ms | 3 → 1 |
| `GET /articles?sort=date_asc` | 19.1 ms | 8.4 ms | 3 → 1 |
| `GET /sources` | 18.4 ms | 7.1 ms | 3 → 1 |

**The trade-off, stated plainly.** The KV counter was already advisory — the
code recorded ~10 % burst overshoot because KV has no compare-and-swap — so
counting per isolate widens the ceiling rather than opening a hole:
Cloudflare keeps one isolate hot per colo, so an ordinary client still lands
in one bucket. A caller who deliberately spread requests across isolates
would see a higher effective limit. The limits are generous (120 reads/min,
5 refreshes/min) and absorb it. If that stops being true, switch to a Rate
Limiting binding and delete `RATE_MEMORY`. A test pins the guarantee — ten
calls from one caller must not write to KV ten times.

**What was rejected.** Memoising the parsed article array and the source-list
ETag were both measured and dropped: each would have removed one KV read per
request, but only by accepting cross-isolate staleness on a cache that
refreshes hourly, and the CPU they saved is under a millisecond.

## Continuous integration

Add the suite beside the existing Android jobs in
[`.circleci/config.yml`](../../.circleci/config.yml) — it reuses the same
Flutter SDK and Gradle caches. Two rules from the e2e `ci` topic apply: the job
boots its own emulator (never shares one with another job), and it runs the
`flutter build apk` step before `npx e2e run` so the suite installs a build the
job just produced.

## Verified runs

Record what ran, where, and with what, so the next session starts from fact:

| Date | Host | Result |
| --- | --- | --- |
| — | — | Not yet run on a device: this repository's working copy had no Android SDK (`adb not found in PATH`), so no emulator run was possible. `flutter analyze` (no issues) and `flutter test` (270 tests, all passed) were run instead. |
