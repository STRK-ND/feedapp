# Changelog: v1.0.0 → v1.0.1

## Release Date: 2026-03-23

---

## 🚀 New Features

### Cloudflare Worker Integration
- Migrated feed fetching to Cloudflare Worker for improved performance and reliability
- Added pagination support with `page` and `pageSize` parameters
- Added filtering capabilities (category, read status, saved status)
- Improved image URL extraction from RSS feeds

### UI/UX Improvements
- **Stitch Design System**: Complete UI redesign with purple theme, full-bleed cards, and Lexend typography
- **Dark Mode Support**: Theme-aware colors throughout the app (Feed, Saved, Settings screens)
- **Bento Grid Layout**: Implemented bento-style grid for Saved Articles view
- **Improved Navigation**: Bottom navigation bar with rounded corners

### Notifications
- **In-App Notifications**: Complete notification system implementation
- **Push Notifications**: Firebase Cloud Messaging integration ready

### Analytics & Tracking
- Firebase Analytics integration for tracking user behavior
- Share event logging

---

## 🐛 Bug Fixes

### Critical Fixes (v1.0.1)
- Removed unused freezed dependency (fixed build error)
- Fixed missing GetIt import in article_detail_screen.dart
- Fixed type error in read_time_badge.dart (passed article.description)
- Fixed static access to RssFeedService.predefinedSources
- Fixed test infrastructure - GetIt service locator re-registration

### Previous Fixes
- Handled int IDs from Worker API in Article.fromJson
- Prevented infinite loop in Saved tab didUpdateWidget
- Improved article save functionality with proper list mutation
- Fixed theme-aware icon visibility in dark mode

---

## 📦 Dependencies Updated

| Package | Version | Change |
|---------|---------|--------|
| Firebase | 3.8.0+ | Updated |
| Firebase Analytics | 11.6.0+ | Updated |
| Firebase Messaging | 15.1.6+ | Updated |
| get_it | 7.6.4+ | Updated |
| provider | 6.1.2+ | Updated |
| google_fonts | 8.0.1+ | Updated |

---

## 🏗️ Architecture Changes

### New Components
- `lib/models/paginated_response.dart` - Pagination helpers
- `lib/models/filter_params.dart` - Filter parameters
- `lib/models/in_app_notification.dart` - Notification model
- `lib/providers/feed_provider.dart` - Feed state management
- `lib/providers/theme_provider.dart` - Theme management
- `lib/services/analytics_service.dart` - Analytics tracking
- `lib/services/in_app_notification_manager.dart` - In-app notifications
- `lib/services/notification_service.dart` - Push notifications
- `lib/services/worker_feed_service.dart` - Worker API client

### Refactored
- `lib/repositories/article_repository.dart` - Added paginated API support
- `lib/services/rss_feed_service.dart` - Improved feed fetching

---

## 📱 Build Configuration

- Version bumped: 1.0.0 → 1.0.1
- App name updated: "Curated Feeds v1.0.1"
- Removed iOS, macOS, Linux, Windows, Web platforms (Android-only build)
- Added Android adaptive icons

---

## ✅ Testing

- All 110 tests passing
- Added PaginatedResponse model tests
- Improved repository tests with proper GetIt setup

---

## ⚠️ Known Issues (Deferred)

- Some deprecated warnings remain (withOpacity, Share class)
- Unused imports and variables (code cleanup for future release)
- FlutterFire dependencies have newer versions available

---

## 📄 Files Changed

- **284 files** changed
- **+15,439** additions
- **-5,781** deletions

---

*Generated on 2026-03-23*