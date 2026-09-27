# Changelog

All notable changes to Curated Feeds will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Security (from the run-2 audit)
- Worker: app-level authorization now fails closed when `API_SECRET` is unset — `/subscribe` and `/articles/refresh` are no longer open by default (reads stay public)
- Worker: subscription tokens are capped at 4096 chars on POST/DELETE `/subscribe`
- Worker: future-dated feed items (>24h ahead) are dropped at ingestion so they cannot pin clients' delta watermarks
- Worker: 500 responses no longer echo exception text to callers
- OTA: in-app updater verifies the APK against the release's `SHA256SUMS` asset (published by CI) before install; mismatch or missing checksums fail closed to the browser fallback
- OTA: `triggerInstall` now refuses any download handle that was not checksum-verified
- CI: release workflow gains a provenance check (tag must be on master) and a manual approval hold before signing/publishing
- CI: signed builds require a pinned `FLUTTER_COMMIT` env var and verify the cloned SDK SHA before use
- CI: releases publish a `SHA256SUMS-<tag>.txt` asset; `--dart-define` expansions are now quoted
- Client: delta-fetch watermark is clamped against the clock — a future-dated cached article falls back to a full fetch
- Client: Open-in-browser launches only http(s) links (no `intent://` or other app-handoff schemes)
- Client: source registry rejects non-http(s) feed URLs, mirroring the server's `handlePutSources` rule

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

## [1.0.0] - 2026-03-03

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
