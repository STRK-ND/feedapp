# Releasing — free in-app OTA updates (CircleCI → GitHub Releases)

The app ships with a complete OTA update system. CI runs on **CircleCI**
(migrated from GitHub Actions in 2026-08); publishing a release is a
two-command operation, and everything it uses is free:

| Piece | What it does | Cost |
| --- | --- | --- |
| `lib/services/update_service.dart` + `lib/widgets/update_dialog.dart` | Checks GitHub Releases hourly, compares versions, in-app APK download with progress → Android system installer (browser fallback) | — |
| `.circleci/config.yml` | `verify` (format/analyze/tests) on every push · `build_signed` (signed APK + AAB) on master · `release` on a `v*` tag → publishes the GitHub Release | CircleCI free credits |
| GitHub Releases | Hosts the APK/AAB artifacts the app downloads | Free (2 GB per file) |

No Play Store account, no server, no backend. Releases are signed with the
same `upload-keystore.jks` used for local builds (its SHA-1 is registered in
Firebase), so updates install straight over existing installs.

## 1. One-time setup: CircleCI

1. **Connect the project**: [circleci.com](https://circleci.com) → sign in
   with GitHub → **Projects** → **Set Up Project** next to `STRK-ND/feedapp`
   → choose "Fastest: use the `.circleci/config.yml` in this repo". The
   first push after connecting triggers `verify` + `build_signed`.
2. **Environment variables** (Project Settings → Environment Variables) —
   the build and release jobs fail without them:

   | Variable | Value |
   | --- | --- |
   | `UPLOAD_KEYSTORE_BASE64` | `upload-keystore.jks` encoded: `certutil -encode android\app\upload-keystore.jks ks.txt` (paste the file body, no headers) |
   | `KEYSTORE_PASSWORD` | `storePassword` from `android/key.properties` |
   | `KEY_PASSWORD` | `keyPassword` from `android/key.properties` |
   | `KEY_ALIAS` | `keyAlias` from `android/key.properties` (`cf-upload`) |
   | `GOOGLE_SERVICES_JSON` | Contents of `android/app/google-services.json` |
   | `WORKER_API_SECRET` | The Cloudflare Worker API secret |
   | `GITHUB_TOKEN` | A GitHub PAT (classic) with **repo** scope, or a fine-grained token with **Contents: read & write** on this repo — used to publish the GitHub Release |

   (The old GitHub Actions secrets can be deleted from the repo settings —
   the Actions workflows no longer exist.)

## 1b. Worker secrets (one-time, via wrangler)

The worker's authority model (audit-hardened):

| Secret | Scope | Notes |
| --- | --- | --- |
| `API_SECRET` | app-shared | embedded in the APK (authenticates `/subscribe`, `/articles/refresh`) — treat as public, not a boundary |
| `ADMIN_SECRET` | admin-only | **required** for `PUT /sources` (overrides the canonical list for every user). Never embed in the app. Admin requests fail closed when unset. |

```powershell
cd workers
npx wrangler secret put ADMIN_SECRET   # long random value, keep in a vault
npx wrangler secret put API_SECRET     # must match --dart-define=WORKER_API_SECRET used in builds
```

`PUT /sources` is then only callable with `x-api-secret: $ADMIN_SECRET`
(comparison is timing-safe). Verification is covered by the worker tests
("PUT /sources is admin-only…" et al.).

## 2. Every release

```powershell
# 1. Bump the version in pubspec.yaml (e.g. 1.0.0+23 -> 1.0.1+24), commit
git add pubspec.yaml
git commit -m "chore: bump version to 1.0.1"

# 2. Tag and push — CircleCI does the rest
git tag v1.0.1
git push origin master v1.0.1
```

The `release` job then: syncs pubspec version to the tag (versionCode
floored at 22 + build number) → format/analyze/tests → signed APK + AAB →
creates the GitHub Release `v1.0.1` with `curated-feeds-v1.0.1.apk` / `.aab`
and auto-generated notes. Watch progress under the project's **Pipelines**
tab on CircleCI. Re-running a failed release job is safe: if the release
already exists, assets are uploaded to it instead of failing.

## 3. How users receive the update

Nothing to do. Installed apps check `releases/latest` on feed-screen load
(throttled to once/hour) or via **Check for updates** in the feed menu, get
the update dialog with release notes, download in-app with a progress bar,
and the Android system installer takes over. Users who don't open the app
also get a heads-up notification. A user who dismissed the dialog isn't
nagged again for that version ("ignore").

## Rules that keep it working

- **Tag version must be strictly newer** than what users run
  (`1.0.1 > 1.0.0`; the comparison ignores the `v` prefix and build number).
- **Never lose `upload-keystore.jks`** — a different signature means Android
  refuses the update and users must uninstall first. Keep a backup outside
  the repo (it is deliberately git-ignored).
- **Attach the APK as a release asset** (the release job does): the updater
  picks the first `*.apk` asset from the latest release; if a release has no
  APK asset, the dialog falls back to opening the release page in a browser.
- **Keep `FLUTTER_VERSION` in sync** across the three jobs in
  `.circleci/config.yml`; bump it deliberately (the pin is what keeps
  release builds reproducible).
- **Forks** can point the updater at their own releases with
  `--dart-define=UPDATES_REPO=owner/name`.


