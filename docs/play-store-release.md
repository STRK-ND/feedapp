# Play Store Release Process

Curated Feeds ships through two channels from the same source:

| | `play` flavor | `direct` flavor |
|---|---|---|
| Distributed via | Google Play (AAB) | GitHub Releases (APK/AAB) |
| Self-update (OTA) | No — store only | Yes — GitHub Releases updater |
| `REQUEST_INSTALL_PACKAGES` | No | Yes |
| Free saved-articles cap | 5 | 25 |
| Pro unlock | Play purchase (+ local verified flag) | Local flag (+ cloud mirror) |
| Dart define | `PLAY_STORE_BUILD=true` | — |

## Version scheme

- Play line starts at **1.0.0+26** (`pubspec.yaml` `version: 1.0.0+26`).
- 26 > 25 (the last sideloaded 1.0.2+25), so any Play install supersedes any sideloaded build and store updates always outrank it.
- Bump `version` before every Play upload; never reuse a versionCode, even for a rejected submission.

## Build commands

```bash
# Play upload (AAB, self-update compiled out, no install permission)
flutter build appbundle --release --flavor play \
  --dart-define=WORKER_API_SECRET=$WORKER_API_SECRET \
  --dart-define=PLAY_STORE_BUILD=true

# Direct channel (what CircleCI publishes to GitHub Releases)
flutter build appbundle --release --flavor direct \
  --dart-define=WORKER_API_SECRET=$WORKER_API_SECRET
flutter build apk --release --flavor direct \
  --dart-define=WORKER_API_SECRET=$WORKER_API_SECRET
```

CI (`release` workflow) builds both; the Play AAB lands as a CircleCI
artifact (`app-play-release.aab`) for manual store upload. The GitHub
Release itself carries only the direct APK/AAB + SHA256SUMS.

## Play Console requirements (owner checklist)

- [ ] Play Console → App signing: accept **Play App Signing** (Google holds the release key; upload key = the existing upload keystore via CI)
- [ ] Data safety form: app collects account email/display name (Firebase Auth), reading history (Firestore sync, user-triggered), diagnostics (Crashlytics/Sentry); no data sold, encrypted in transit
- [ ] Content rating questionnaire (no user-generated content sharing; news content)
- [ ] Target audience: adults; news app → no special-category declarations needed
- [ ] Store listing: free tier = 5 saved articles + 2 locked reader themes; Pro = one-time `cf_pro_lifetime`
- [ ] Privacy policy URL: must describe Firebase Auth/Analytics/Crashlytics/Sentry/PostHog data flows (see docs/monitoring-setup.md)
- [ ] Account deletion: users can delete their Firestore tenant data via account removal — verify flow before submission

## Policy notes baked into the code

- **No self-update on Play**: `AppConfig.isPlayStoreBuild` gates `checkForUpdates`, `announceUpdate`, and hides the update menu entry; the play flavor manifest omits `REQUEST_INSTALL_PACKAGES`. Any future re-introduction of download code on Play will trip store review.
- **Billing**: the app uses Google Play Billing (`com.android.vending.BILLING`) for `cf_pro_lifetime`; the GitHub/direct monetization path must never be offered inside the Play build (no external purchase links in that flavor).
- **News content**: article sources are curated in-repo (`workers/feed-worker.js` + admin override), so content policy responsibility sits with the operator.

## First-upload flow

1. Bump version in `pubspec.yaml`; update CHANGELOG.
2. Tag `v1.0.0` and push → CircleCI release pipeline (provenance check → approval hold → build → publish).
3. Download the `app-play-release.aab` artifact from CircleCI.
4. Play Console → Production → Create release → upload AAB → submit for review.
