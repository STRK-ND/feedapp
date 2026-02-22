# External Integrations

**Analysis Date:** 2026-02-22

## APIs & External Services

**Content Feeds:**
- Public RSS feeds - Primary data source for news and articles
  - Implementation: `lib/services/rss_feed_service.dart`, `lib/providers/feed_providers.dart`
  - Auth: None (public RSS feeds)
  - Sources include:
    - CNN Top Stories (rss.cnn.com/rss/cnn_topstories.rss)
    - The Verge (www.theverge.com/rss/index.xml)
    - TechCrunch (techcrunch.com/feed/)
    - Hacker News (hnrss.org/frontpage)
    - BBC World News (feeds.bbci.co.uk/news/rss.xml)
    - ESPN Top (www.espn.com/espn/rss/news)
    - Science Daily (www.sciencedaily.com/rss/top.xml)
    - Variety (variety.com/feed/)

**Article Content:**
- Public HTTP APIs - Full article content fetching from URLs
  - Implementation: `lib/services/article_content_service.dart`
  - Auth: None (public web pages)
  - Domain-specific extraction patterns for: techcrunch.com, theverge.com, bbc.com, cnn.com

## Data Storage

**Databases:**
- None (no external database services used)

**Local Storage:**
- flutter_secure_storage - Encrypted local key-value storage
  - Connection: Managed by `FlutterSecureStorage` class
  - Client: Storage service wrapper in `lib/services/storage_service.dart`
  - Android: EncryptedSharedPreferences
  - iOS: Keychain (first_unlock accessibility)
  - Stored data: Articles list, saved articles, last refresh time, view mode preferences

**File Storage:**
- Local filesystem only - Image and content caching
  - Client: flutter_cache_manager in `lib/services/cache_manager.dart`
  - Cache locations: App-specific directories via path_provider
  - Cached content: Network images, APK downloads

**Caching:**
- Multi-layer caching strategy:
  - Memory cache: In-memory image caching via cached_network_image
  - Disk cache: flutter_cache_manager for persistent storage
  - Secure storage: User preferences and article data

## Authentication & Identity

**Auth Provider:**
- None (no external authentication required)
  - No user accounts or login system
  - No OAuth, JWT, or token-based authentication
  - App is completely self-contained with no user-specific data

## Monitoring & Observability

**Error Tracking:**
- None (no third-party error tracking services)

**Logs:**
- debugPrint - Flutter debug logging
  - Implementation: Uses Flutter's built-in debugPrint throughout codebase
  - Centralized error handling: `lib/utils/error_handler.dart`
  - Error severity levels: low, medium, high
  - Log categories: RSS fetching, article parsing, storage operations

**Crash Reporting:**
- Not configured

## CI/CD & Deployment

**Hosting:**
- Multi-platform app stores (not configured in codebase)
  - Google Play Store (Android APK/AAB)
  - Apple App Store (iOS IPA)
  - Other platforms: Windows, Linux, macOS, Web (direct deployment)

**CI Pipeline:**
- GitHub Actions (`.github/workflows/` directory exists)
  - Workflows not explicitly defined in analyzed files
  - May contain automated testing and build pipelines

**Update Checking:**
- Self-contained update system
  - Implementation: `lib/services/update_service.dart`, `lib/services/version_provider.dart`
  - APK downloader: `lib/services/apk_downloader.dart`
  - Custom version checking mechanism (no external update service)

## Environment Configuration

**Required env vars:**
- None (app does not use environment variables)
  - All configuration is in code (constants.dart, feed_providers.dart)
  - No API keys or secrets required
  - No database connection strings
  - No third-party service credentials

**Secrets location:**
- No external secrets management
  - All data stored locally via flutter_secure_storage
  - No cloud-based secret storage services

## Webhooks & Callbacks

**Incoming:**
- None (no webhook endpoints configured)

**Outgoing:**
- None (no webhook or callback notifications sent)
  - App is pull-only (fetches RSS feeds on demand)
  - No push-based data synchronization
  - No notification services configured

## Network Communication

**HTTP Client:**
- http package (`package:http/http.dart`)
  - Used for: RSS feed fetching, article content fetching
  - Response handling: Status code validation, timeout configuration
  - Custom headers: User-Agent, Accept, Accept-Encoding for specific feeds

**Connectivity:**
- connectivity_plus package
  - Monitors network state changes
  - Implementation: Used for detecting online/offline status

**SSL/TLS:**
- Standard HTTPS for all external requests
  - No custom SSL certificates
  - No SSL pinning configured

---

*Integration audit: 2026-02-22*
