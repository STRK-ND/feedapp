# CI/CD Setup — Curated Feeds

Pipelines:
- **GitHub Actions** — `ci.yml` (PR + master), `build.yml` (master signed build), `release.yml` (tag v*.*.* Release)
- **CircleCI** — `config.yml` (analyze + test on all branches, build on master)

Both run in parallel. Either can fail the build.

---

## Secrets to configure in GitHub

Path: https://github.com/STRK-ND/feedapp/settings/secrets/actions

| Secret name | Value |
|---|---|
| `UPLOAD_KEYSTORE_BASE64` | base64 of `android/app/upload-keystore.jks` |
| `KEYSTORE_PASSWORD` | contents of `android/key.properties` `storePassword` field |
| `KEY_ALIAS` | `cf-upload` |
| `KEY_PASSWORD` | contents of `android/key.properties` `keyPassword` field |
| `GOOGLE_SERVICES_JSON` | contents of `android/app/google-services.json` (single line is fine) |

## Secrets to configure in CircleCI

Path: https://app.circleci.com/settings/project/github/STRK-ND/feedapp/environment-variables

Same 5 variables, same values.

---

## Generating the values locally

```powershell
# 1. Keystore base64 (upload to GitHub + CircleCI as UPLOAD_KEYSTORE_BASE64)
cd D:\CRM\myapp
[Convert]::ToBase64String([IO.File]::ReadAllBytes('android\app\upload-keystore.jks'))

# 2. Passwords — copy storePassword / keyPassword / keyAlias from android/key.properties
Get-Content android\key.properties

# 3. google-services.json — paste the entire contents as one-line
Get-Content android\app\google-services.json -Raw
```

---

## What runs when

### PR to any branch
- CircleCI `checks` runs `flutter analyze` + `flutter test`
- CircleCI runs the same
- PR can't be merged until both pass (require status checks in repo settings)

### Push to `master`
- Same checks
- CircleCI `build_signed` builds the direct APK, direct AAB, and Play AAB with the release signing config
- Outputs stored as CircleCI artifacts

### Tag push `v1.0.1` (or any `v*`)
- CircleCI `release` workflow runs: provenance check → manual approval → checks → build → publish
- Creates GitHub Release titled `v1.0.1` with four assets:
  - `Curated Feeds v1.0.1.apk`
  - `Curated Feeds v1.0.1.aab`
  - `Curated Feeds v1.0.1-play.aab`
  - `SHA256SUMS-v1.0.1.txt`
- Auto-generated release notes from commit history
- UpdateService (in-app OTA) is triggered when the user's app next runs (direct flavor only)
- The tag version must match pubspec.yaml, and the synced versionCode is floored at 26 (Play baseline; the sideload line ended at 1.0.2+25) — see docs/releasing.md

---

## Cutting a release

```powershell
cd D:\CRM\myapp
# Bump pubspec.yaml first (versionCode must exceed the last published build), commit, then:
git tag v1.0.1
git push origin master v1.0.1
```

Then watch the CircleCI pipeline (https://app.circleci.com/pipelines/github/STRK-ND/feedapp). After the approval hold, the Release is live at https://github.com/STRK-ND/feedapp/releases.

---

## Worker deploy

Worker deploy is currently **manual only**:
```
cd D:\CRM\myapp\workers
wrangler deploy
```

If you later want this in CI, add a secret `CLOUDFLARE_API_TOKEN` and uncomment the deploy step (not currently included — pegged as manual in scope).

---

## Required GitHub status checks (set these once)

https://github.com/STRK-ND/feedapp/settings/branch_protection_rules
- `Flutter analyze`
- `Flutter test`
- `analyze-and-test` (CircleCI)

Master should require all of them to pass before merge.
