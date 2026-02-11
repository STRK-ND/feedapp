# External Integrations

**Analysis Date:** 2026-02-11

## APIs & External Services

**RSS Feed APIs:**
- TechCrunch - `https://techcrunch.com/feed/`
  - Purpose: Technology news feed
  - Client: HTTP requests via `http` package (`lib/main.dart`)
- The Verge - `https://www.theverge.com/rss/index.xml`
  - Purpose: Technology news feed
  - Client: HTTP requests via `http` package
- Hacker News - `https://hnrss.org/frontpage`
  - Purpose: Tech/startup news feed
  - Client: HTTP requests via `http` package
- BBC World - `http://feeds.bbci.co.uk/news/rss.xml`
  - Purpose: World news feed
  - Client: HTTP requests via `http` package
- CNN Top Stories - `http://rss.cnn.com/rss/cnn_topstories.rss`
  - Purpose: US news feed
  - Client: HTTP requests via `http` package
- Science Daily - `https://www.sciencedaily.com/rss/top.xml`
  - Purpose: Science news feed
  - Client: HTTP requests via `http` package
- ESPN Top - `https://www.espn.com/espn/rss/news`
  - Purpose: Sports news feed
  - Client: HTTP requests via `http` package
- Variety - `https://variety.com/feed/`
  - Purpose: Entertainment news feed
  - Client: HTTP requests via `http` package

**GitHub API:**
- GitHub Releases API - `https://api.github.com/repos/STRK-ND/feedapp/releases/latest`
  - SDK/Client: HTTP requests via `http` package
  - Auth: No authentication required (public API)
  - Purpose: Auto-update checking in `lib/services/update_service.dart`
  - Headers: `Accept: application/vnd.github.v3+json`

## Data Storage

**Databases:**
- None (no external database)

**Local Storage:**
- SharedPreferences (implemented via `shared_preferences` package)
  - Location: Platform-specific storage (Android: SharedPreferences, iOS: NSUserDefaults, etc.)
  - Client: `shared_preferences` ^2.5.4
  - Purpose: Persist app settings, update check timestamps, ignored versions

**File Storage:**
- Local filesystem only (via `path_provider`)
  - Client: `path_provider` ^2.1.5
  - Temporary directory: For APK downloads (`lib/services/apk_downloader.dart`)
  - Downloaded APKs: Stored in temp directory, cleaned up after 7 days

**Caching:**
- Cached network images (via `cached_network_image` package)
  - Client: `cached_network_image` ^3.4.1
  - Purpose: Cache RSS article images to reduce bandwidth

## Authentication & Identity

**Auth Provider:**
- None (no external authentication required)
- The app is a standalone RSS reader with no user accounts

## Monitoring & Observability

**Error Tracking:**
- None (uses `debugPrint` for console logging only)

**Logs:**
- Approach: Console-based debugging via `debugPrint()` calls in `lib/main.dart`, `lib/services/update_service.dart`, and `lib/services/apk_downloader.dart`

## CI/CD & Deployment

**Hosting:**
- GitHub Releases - APK distribution
  - Repository: STRK-ND/feedapp
  - Trigger: Tag push (`v*.*.*`), workflow_dispatch

**CI Pipeline:**
- Service: GitHub Actions
  - Config: `.github/workflows/build.yml`
  - Runner: ubuntu-latest
  - Java: 17 (temurin distribution)
  - Flutter: 3.38.9 (stable channel)
  - Steps:
    1. Checkout code
    2. Setup Java 17
    3. Setup Flutter 3.38.9
    4. Get dependencies (`flutter pub get`)
    5. Build APK (`flutter build apk --release`)
    6. Extract version from tag
    7. Generate changelog from `CHANGELOG.md`
    8. Create GitHub Release with `app-release.apk`

## Environment Configuration

**Required env vars:**
- None - Application is fully self-contained

**Secrets location:**
- None required - No API keys or secrets needed (GitHub API is public)

**Configuration files:**
- `pubspec.yaml` - Dependencies and Flutter config
- `android/gradle.properties` - Gradle build settings
- `android/app/build.gradle.kts` - Android app build config
- `analysis_options.yaml` - Dart analyzer configuration

## Webhooks & Callbacks

**Incoming:**
- None

**Outgoing:**
- None

**HTTP Client Configuration:**
- Timeout: 8 seconds for RSS feed fetches (`lib/main.dart`)
- Timeout: 10 seconds for GitHub API calls (`lib/services/update_service.dart`)
- Retry logic: None (fail-fast on errors)

---

*Integration audit: 2026-02-11*
