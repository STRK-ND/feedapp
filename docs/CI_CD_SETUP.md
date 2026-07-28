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
- GHA `ci.yml` runs `flutter analyze` + `flutter test`
- CircleCI runs the same
- PR can't be merged until both pass (require status checks in repo settings)

### Push to `master`
- Same checks
- GHA `build.yml` runs `flutter build apk --release` + `flutter build appbundle --release`
- Outputs uploaded as GitHub Actions artifact (30-day retention)
- CircleCI does the same and stores as CircleCI artifacts

### Tag push `v1.0.1` (or any `v*`)
- GHA `release.yml` runs full check + build
- Creates GitHub Release titled `v1.0.1` with two assets:
  - `curated-feeds-v1.0.1.apk`
  - `curated-feeds-v1.0.1.aab`
- Auto-generated release notes from commit history
- UpdateService (in-app OTA) is triggered when the user's app next runs
- pubspec.yaml is auto-synced to match the tag (`version: 1.0.1+1`)

---

## Cutting a release

```powershell
cd D:\CRM\myapp
git tag v1.0.1
git push origin v1.0.1
```

Then watch https://github.com/STRK-ND/feedapp/actions. ~10 minutes later the Release is live at https://github.com/STRK-ND/feedapp/releases.

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
