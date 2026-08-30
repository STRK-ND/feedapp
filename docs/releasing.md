# Releasing — free in-app OTA updates via GitHub Releases

The app ships with a complete OTA update system. Publishing a release is a
two-command operation, and everything it uses is free:

| Piece | What it does | Cost |
| --- | --- | --- |
| `lib/services/update_service.dart` + `lib/widgets/update_dialog.dart` | Checks GitHub Releases hourly, compares versions, in-app APK download with progress → Android system installer (browser fallback) | — |
| `.github/workflows/release.yml` | On a `v*` tag: analyze + tests → **signed** APK + AAB → publishes the GitHub Release | GitHub Actions (free) |
| GitHub Releases | Hosts the APK/AAB artifacts the app downloads | Free (2 GB per file) |

No Play Store account, no server, no backend. The release workflow signs with
the same `upload-keystore.jks` used for local builds (its SHA-1 is registered
in Firebase), so updates install straight over existing installs.

## 1. One-time setup: repo secrets

GitHub → **STRK-ND/feedapp → Settings → Secrets and variables → Actions**,
add all six. The release workflow fails without them:

| Secret | Value |
| --- | --- |
| `UPLOAD_KEYSTORE_BASE64` | `upload-keystore.jks` encoded: `certutil -encode android\app\upload-keystore.jks ks.txt` (paste the file body, no headers) |
| `KEYSTORE_PASSWORD` | `storePassword` from `android/key.properties` |
| `KEY_PASSWORD` | `keyPassword` from `android/key.properties` |
| `KEY_ALIAS` | `keyAlias` from `android/key.properties` (`cf-upload`) |
| `GOOGLE_SERVICES_JSON` | Contents of `android/app/google-services.json` |
| `WORKER_API_SECRET` | The Cloudflare Worker API secret (`wrangler secret put API_SECRET` value) |

## 2. Every release

```powershell
# 1. Bump the version in pubspec.yaml (e.g. 1.2.3+22 -> 1.2.4+23), commit
git add pubspec.yaml
git commit -m "chore: bump version to 1.2.4"

# 2. Tag and push — CI does the rest
git tag v1.2.4
git push origin master v1.2.4
```

The workflow then: decodes the keystore → syncs pubspec version to the tag
(versionCode floored at 22 + run number) → `flutter analyze` + `flutter test`
→ builds signed APK + AAB → creates the GitHub Release with
`curated-feeds-v1.2.4.apk` / `.aab` and auto-generated notes. Watch progress
under the repo's **Actions** tab.

## 3. How users receive the update

Nothing to do. Installed apps check `releases/latest` on feed-screen load
(throttled to once/hour) or via **Check for updates** in the feed menu, get
the update dialog with release notes, download in-app with a progress bar,
and the Android system installer takes over. Users who don't open the app
also get a heads-up notification. A user who dismissed the dialog isn't
nagged again for that version ("ignore").

## Rules that keep it working

- **Tag version must be strictly newer** than what users run
  (`1.2.4 > 1.2.3`; the comparison ignores the `v` prefix and build number).
- **Never lose `upload-keystore.jks`** — a different signature means Android
  refuses the update and users must uninstall first. Keep a backup outside
  the repo (it is deliberately git-ignored).
- **Attach the APK as a release asset** (the workflow does): the updater
  picks the first `*.apk` asset from the latest release; if a release has no
  APK asset, the dialog falls back to opening the release page in a browser.
- **Forks** can point the updater at their own releases with
  `--dart-define=UPDATES_REPO=owner/name`.
