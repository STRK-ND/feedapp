# Architecture

**Analysis Date:** 2026-02-11

## Pattern Overview

**Overall:** Monolithic StatefulWidget with setState-based state management

**Key Characteristics:**
- Single-file application architecture with minimal separation of concerns
- Direct state management via StatefulWidget's setState() method
- SharedPreferences for persistent local storage
- Service classes isolated in `lib/services/` directory
- No external state management libraries (no Provider, Riverpod, BLoC)
- No dependency injection framework
- All data models, UI components, and business logic co-located in main entry file

## Layers

**UI Layer:**
- Purpose: Renders article cards, navigation, and user interactions
- Location: `lib/main.dart` (SwipeableCard, CardStack, RssFeedScreen classes)
- Contains: Widget classes, animation controllers, gesture handlers
- Depends on: Article models, RssFeedService, UpdateService, SharedPreferences
- Used by: Flutter runtime

**Service Layer:**
- Purpose: External API calls and business logic for updates
- Location: `lib/services/` (update_service.dart, apk_downloader.dart)
- Contains: UpdateService, ApkDownloader, version checking logic
- Depends on: http package, SharedPreferences, package_info_plus
- Used by: RssFeedScreen

**Data Layer:**
- Purpose: Data models and RSS parsing logic
- Location: `lib/main.dart` (Article, RssSource, RssFeedService classes)
- Contains: Data models with JSON serialization, RSS XML parsing, image extraction
- Depends on: http package, xml package, no local database
- Used by: UI layer and Service layer

**Persistence Layer:**
- Purpose: Local data storage for articles, favorites, settings
- Location: SharedPreferences (Flutter package)
- Contains: Articles cache, saved articles, view mode, update check timestamps
- Depends on: shared_preferences package
- Used by: RssFeedScreen, UpdateService

## Data Flow

**Article Feed Loading:**

1. `_refreshFeeds()` in RssFeedScreen called on app startup or refresh
2. Connectivity check via connectivity_plus
3. RssFeedService.fetchAllArticles() calls parallel HTTP requests to RSS feeds
4. Each RSS XML response parsed via _parseRssXml()
5. Image URLs extracted via multiple fallback methods (enclosure, media:content, HTML parsing)
6. New Article objects created and merged with existing cached articles
7. List sorted by publication date (newest first)
8. Articles saved to SharedPreferences via _saveArticles()
9. UI updated via setState()

**Article Browsing:**

1. User swipes/taps on SwipeableCard
2. Gesture handlers update article state (isRead, isSaved)
3. Article moved between _articles and _savedArticles lists
4. Changes persisted to SharedPreferences
5. Displayed articles list refreshed via _getFilteredArticles()

**Version Update Flow:**

1. _checkForUpdates() triggered 2 seconds after app start
2. UpdateService.checkForUpdates() queries GitHub Releases API
3. Version comparison against current app version
4. UpdateDialog widget shown if update available
5. User action opens download URL via url_launcher

**State Management:**
- Local state stored in _RssFeedScreenState class properties
- UI updates via setState() method
- Persistence via SharedPreferences for cross-session data
- No reactive streams or state management framework

## Key Abstractions

**Article Model:**
- Purpose: Represents a single RSS feed item with metadata
- Examples: `lib/main.dart` (lines 156-218)
- Pattern: Plain Dart class with toJson/fromJson serialization, mutable boolean flags

**RssSource Model:**
- Purpose: Represents an RSS feed configuration with category and styling
- Examples: `lib/main.dart` (lines 116-154)
- Pattern: Config object with predefined instances in RssFeedService.predefinedSources

**RssFeedService:**
- Purpose: Fetches and parses RSS XML from external feed URLs
- Examples: `lib/main.dart` (lines 221-601)
- Pattern: Static service class with async methods, multiple image extraction strategies

**UpdateService:**
- Purpose: Checks GitHub Releases for new app versions
- Examples: `lib/services/update_service.dart`
- Pattern: Static service class with throttling, version comparison, persistence

**SwipeableCard Widget:**
- Purpose: Tinder-style swipe interaction for articles
- Examples: `lib/main.dart` (lines 605-816)
- Pattern: StatefulWidget with gesture detection, animations, rotation physics

## Entry Points

**Main Application Entry:**
- Location: `lib/main.dart` (line 15: void main())
- Triggers: App launch by Flutter runtime
- Responsibilities: Instantiates RssReaderApp (MaterialApp) with theme and home route

**RssFeedScreen:**
- Location: `lib/main.dart` (lines 1465+)
- Triggers: App initialization (set as home route of MaterialApp)
- Responsibilities: Primary screen with tabs, article display, state management, connectivity monitoring

**Update Check:**
- Location: `lib/main.dart` (line 1585: _checkForUpdates())
- Triggers: 2 seconds after app start (delayed initialization in initState)
- Responsibilities: Queries GitHub API for latest release, shows update dialog if available

## Error Handling

**Strategy:** Silent fallback with debug logging

**Patterns:**
- HTTP errors return empty article lists, log error messages via debugPrint
- Network timeouts trigger offline state display with cached content
- JSON parsing failures return fallback defaults (e.g., '1.0.0' version)
- UI shows error messages in SnackBar widgets for user feedback
- Connectivity status monitored via connectivity_plus with automatic retry on reconnection

## Cross-Cutting Concerns

**Logging:** debugPrint() calls throughout for development debugging (no production logging framework)

**Validation:** Minimal validation - version comparison handles malformed inputs, XML parsing wrapped in try-catch blocks

**Authentication:** Not applicable - app consumes public RSS feeds, no user authentication

---

*Architecture analysis: 2026-02-11*
