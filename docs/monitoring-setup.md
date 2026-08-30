# Monitoring Setup (Crashlytics + Sentry + PostHog)

The app ships with all three observability tools wired. Firebase
Crashlytics is **live immediately**; Sentry and PostHog activate as soon
as you add their keys to the build command — no code changes needed, and
keys are never stored in the repo.

| Tool | Role | Status |
| --- | --- | --- |
| Firebase Crashlytics | crash reports (fatal + background isolate) | live |
| Sentry (`sentry_flutter`) | handled/non-fatal errors, breadcrumbs | needs `SENTRY_DSN` |
| PostHog (`posthog_flutter`) | product analytics events (mirrors `AnalyticsService`) | needs `POSTHOG_API_KEY` |

## 1. Firebase Crashlytics — nothing to do

Already enabled on project `curatedfeeds` (API enabled, Gradle plugin
applied). Collection is disabled for debug builds; the dashboard fills up
from release builds:

- Dashboard: <https://console.firebase.google.com/project/curatedfeeds/crashlytics>

Test it end-to-end with a forced crash in a **release** build:

```dart
FirebaseCrashlytics.instance.crash(); // temporary, then remove
```

## 2. Sentry — one free account + one DSN

1. Create a free account at <https://sentry.io>, create a project with
   platform **Flutter**.
2. Copy the DSN (Settings → Client Keys / shown at project creation).
3. Build with it:

```powershell
flutter build apk --release `
  --dart-define=SENTRY_DSN=<your-dsn> `
  --dart-define=FLUTTER_ENV=production `
  --dart-define=RELEASE_VERSION=1.0.0+23
```

Everything else (error capture, severity mapping, breadcrumbs) is already
wired in `lib/main.dart` + `lib/utils/error_handler.dart`.

## 3. PostHog — one free account + one API key

1. Create a free account at <https://posthog.com> (choose US or EU cloud),
   create a project.
2. Copy the **Project API key** (Settings → Project) — it is a public
   ingest token, safe to embed in the app binary.
3. Build with it:

```powershell
flutter build apk --release `
  --dart-define=POSTHOG_API_KEY=<phc_...> `
  --dart-define=POSTHOG_HOST=https://us.i.posthog.com
```

For EU cloud use `--dart-define=POSTHOG_HOST=https://eu.i.posthog.com`.

Events mirror everything `AnalyticsService` logs (app open, article
open/save/share, search, feed refresh, …) and are tagged with the signed-in
user id via `PostHogService.identify`.

## Combining flags

All three can be passed in one build command; order doesn't matter:

```powershell
flutter build apk --release `
  --dart-define=SENTRY_DSN=<dsn> `
  --dart-define=POSTHOG_API_KEY=<key> `
  --dart-define=POSTHOG_HOST=https://us.i.posthog.com `
  --dart-define=FLUTTER_ENV=production `
  --dart-define=RELEASE_VERSION=1.0.0+23
```

Without the flags the builds behave exactly as before — Crashlytics
collects in release, Sentry/PostHog stay inert.

