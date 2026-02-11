# Codebase Concerns

**Analysis Date:** 2026-02-11

## Tech Debt

**Monolithic Main File:**
- Issue: `lib/main.dart` contains 2935 lines of code (86% of total Dart code) - all business logic, UI, state management, models, and services in a single file.
- Files: `lib/main.dart`
- Impact: Extremely difficult to maintain, test, and navigate. Makes code review and onboarding difficult. Violates single responsibility principle.
- Fix approach: Extract into modular structure: `lib/models/` (Article, RssSource), `lib/services/` (RssFeedService), `lib/widgets/` (CardStack, SwipeableCard, etc.), `lib/screens/` (RssFeedScreen, SettingsScreen), `lib/utils/` (formatters, constants).

**Test Code Duplication:**
- Issue: `Article` model is redefined in `test/article_test.dart` instead of importing from the main source. Creates maintenance burden as changes must be mirrored.
- Files: `test/article_test.dart` (lines 4-66 duplicate the Article class)
- Impact: Tests may drift from actual implementation. Changes to Article model require updating both files.
- Fix approach: Export the Article model from `lib/main.dart` or move models to a separate `lib/models/` directory and import in tests.

**Hardcoded Version in Settings:**
- Issue: Version number "1.1.3" is hardcoded in settings UI instead of reading from `PackageInfo`.
- Files: `lib/main.dart` (line 2787)
- Impact: Settings will show wrong version after updates. Manual editing required to keep in sync.
- Fix approach: Use `PackageInfo.fromPlatform()` to dynamically fetch version at runtime.

**Dead Code - Unused Methods:**
- Issue: `_isValidImageUrl` method (40+ lines) is defined but never called anywhere in the codebase.
- Files: `lib/main.dart` (lines 481-543)
- Impact: Code bloat, potential confusion for maintainers. Suggests unimplemented feature or abandoned refactoring.
- Fix approach: Remove unused method or implement it if image validation was intended.

**Unused Color Constants:**
- Issue: Secondary color constants defined but never used in the UI.
- Files: `lib/main.dart` (lines 108, 110, 112)
- Impact: Code clutter, unclear design intent.
- Fix approach: Remove unused constants or implement their intended use.

## Known Bugs

**APK Download Compilation Error:**
- Symptoms: Code will not compile. `downloadApk` method tries to access `response.stream` which doesn't exist in `http` package Response type.
- Files: `lib/services/apk_downloader.dart` (lines 33, 46)
- Trigger: Attempting to build the app or use APK download functionality.
- Workaround: None - code is broken.
- Fix approach: Replace streaming approach with simpler download: use `response.bodyBytes` directly, or use `http.Client()` with proper streaming via `send()` method. Also fix line 49 type mismatch (double to int).

**Null Check Inefficiency:**
- Symptoms: Code works but uses outdated pattern.
- Files: `lib/main.dart` (line 2922)
- Cause: Using explicit null check instead of null-aware spread operator.
- Fix approach: Replace `if (trailing != null) trailing` with `if (trailing != null) ...[trailing]` pattern used elsewhere.

## Security Considerations

**Hardcoded API Endpoints:**
- Risk: GitHub repository URL and API endpoint are hardcoded in client code (`update_service.dart`). No way to change without app update.
- Files: `lib/services/update_service.dart` (lines 10-11)
- Current mitigation: Public repository access only. No authentication in client code.
- Recommendations:
  1. Add backend proxy for GitHub API calls to support rate limiting and private repos
  2. Consider adding API endpoint via remote config for future flexibility
  3. Document that `githubApiUrl` must be updated for forks

**No SSL Certificate Pinning:**
- Risk: Man-in-the-middle attacks possible since app doesn't verify SSL certificates beyond system defaults.
- Files: All HTTP requests via http package
- Current mitigation: Relies on platform's default certificate validation.
- Recommendations: Consider certificate pinning for production environments, especially for critical API calls.

**Open External URLs Without Validation:**
- Risk: Article links and update URLs are opened via `url_launcher` without validation.
- Files: `lib/main.dart` (line 1253), `lib/widgets/update_dialog.dart` (line 181), `lib/services/update_service.dart` (line 138)
- Current mitigation: `canLaunchUrl()` checks but URL content not validated.
- Recommendations: Add URL scheme validation (allow only http/https) and domain allowlist if feasible.

## Performance Bottlenecks

 **Unbounded Article Storage:**
- Problem: Articles stored indefinitely in SharedPreferences as JSON strings. No cleanup mechanism for old articles.
- Files: `lib/main.dart` (_saveArticles, _loadData methods)
- Cause: Articles accumulate over time; SharedPreferences has size limits (~1MB typically).
- Improvement path: Implement article expiration policy (e.g., delete articles older than 30 days), add storage quota management, consider using a proper database (sqflite, hive, or drift) instead of SharedPreferences.

**No Response Caching for Images:**
- Problem: Uses `cached_network_image` but no persistent cache configuration shown. Images re-downloaded on app restart potentially.
- Files: `lib/main.dart` (lines 974-1007, 1294-1313)
- Cause: Cache configuration not explicitly set.
- Improvement path: Configure `cached_network_image` with persistent storage cache and max cache size limits.

**Multiple Animation Controllers:**
- Problem: Three separate AnimationControllers (_fabController, _staggerController, _cardEntranceController) running одновременно.
- Files: `lib/main.dart` (lines 1502-1508, 848, 638)
- Cause: Each card has its own animation state. With many list items, this could impact performance.
- Improvement path: Consider using a shared animation provider or limiting number of concurrent animations.

**Feed Fetching Not Cancellable:**
- Problem: `fetchAllArticles` uses `Future.wait` with `eagerError: false` but still waits for all feeds to complete even if user navigates away.
- Files: `lib/main.dart` (lines 586-589)
- Cause: No cancellation token or abort controller.
- Improvement path: Use `CancelableOperation` or similar pattern to cancel ongoing requests when appropriate.

## Fragile Areas

**RSS XML Parsing:**
- Files: `lib/main.dart` (lines 315-479, _parseRssXml method)
- Why fragile: Complex nested logic trying multiple methods to extract images and content. Uses raw regex for HTML parsing. Assumes certain RSS structure. Single malformed RSS feed could cause issues.
- Safe modification: Add unit tests with sample RSS feeds from different sources. Separate image extraction logic into dedicated utility class. Consider using a proper HTML parser instead of regex.
- Test coverage: No tests for XML parsing logic (`test/article_test.dart` only tests Article model JSON serialization).

**Date Parsing:**
- Files: `lib/main.dart` (lines 550-580, _parseDate and _parseCustomDate methods)
- Why fragile: Multiple fallback levels, returns current date as fallback on parse failure. May hide data quality issues.
- Safe modification: Add logging for parse failures, return nullable date instead of fallback, display "Unknown date" in UI for failures.
- Test coverage: Partial - `test/article_test.dart` tests date difference calculations but not parsing logic.

**Card Stack Swipe State Management:**
- Files: `lib/main.dart` (lines 605-1157, SwipeableCard and CardStack classes)
- Why fragile: Complex state tracking with position, rotation, animation phases. Multiple calls to setState during swipe operations. Manual index tracking with `indexOf` lookups.
- Safe modification: Extract swipe state into a proper state management solution (Provider, Riverpod, or Bloc). Add comprehensive widget tests for swipe interactions.
- Test coverage: No widget tests for swipe behavior.

**Article State Synchronization:**
- Files: `lib/main.dart` (_onSwipeRight, _onSwipeLeft, _onToggleSave methods)
- Why fragile: Manual synchronization between `_articles` list and `_displayedArticles`. Manual index lookups to find articles in the main list. This pattern is error-prone.
- Safe modification: Use a proper state management class to track articles with their IDs as keys, not list indices. Ensure operations are idempotent.
- Test coverage: No tests for article state transitions.

## Scaling Limits

**Article List Unbounded:**
- Current capacity: All articles kept in memory, limited only by device RAM.
- Limit: Will crash with ~10,000+ articles due to JSON serialization overhead and SharedPreferences limits.
- Scaling path: Implement pagination, database for storage, and article archiving/expiry.

**Feed Sources Fixed:**
- Current capacity: 8 hardcoded RSS sources in `predefinedSources`.
- Limit: Cannot add new sources without code changes.
- Scaling path: Add feature to manage/customize RSS sources with CRUD operations store in SharedPreferences or database.

**Simultaneous Feed Fetching:**
- Current capacity: Fetches all 8 sources in parallel using `Future.wait`.
- Limit: No rate limiting, could hit API limits if more sources added or sources impose rate limits.
- Scaling path: Add sequential or throttled fetching with configurable concurrency limits.

## Dependencies at Risk

**http package streaming incompatibility:**
- Risk: `apk_downloader.dart` uses `response.stream` which doesn't exist in the current `http` package API.
- Impact: APK download functionality completely broken.
- Files: `lib/services/apk_downloader.dart` (line 46)
- Migration plan: Rewrite download method to use `response.bodyBytes` directly, or use `http.Client().send()` method for proper streaming support.

**Flutter/Dart SDK Version:**
- Risk: SDK requirement is `^3.10.8` which may soon be deprecated.
- Impact: Future Flutter versions may break compatibility.
- Files: `pubspec.yaml` (line 22)
- Migration plan: Update to stable Flutter 3.24+ when ready, test all features thoroughly.

**connectivity_plus changes:**
- Risk: Connectivity checking APIs are platform-dependent and subject to change in recent versions.
- Impact: Online/offline detection may break with plugin updates.
- Files: `lib/main.dart` (lines 1521-1537)
- Migration plan: Monitor connectivity_plus changelog for API changes, add abstraction layer for connectivity checks.

## Missing Critical Features

**No Error Recovery Mechanism:**
- Problem: When feed fetch fails, users see "Failed to load feeds" message and can retry manually. No automatic retry or gradual degradation.
- Files: `lib/main.dart` (lines 1643-1648)
- Blocks: Robust offline experience, poor user perception on network issues.
- Recommendation: Implement exponential backoff retry mechanism, show specific error messages per source that failed, allow partial successful loads.

**No Article Deduplication:**
- Problem: If feed is refreshed, duplicate articles (same link) may be added to the list multiple times.
- Files: `lib/main.dart` (lines 1630-1631 uses ID-based check but ID is `link.hashCode`, not robust)
- Blocks: Data quality, confusing user experience.
- Recommendation: Store article URls in a Set for deduplication. Use more stable ID generation or full URL comparison.

**No Local Notifications:**
- Problem: Users must manually check for new articles. No push or scheduled notifications for new content.
- Files: None
- Blocks: User engagement.
- Recommendation: Add local notification plugin and background refresh capability to notify users of new articles.

**No User Preferences Beyond View Mode:**
- Problem: Only view mode preference is saved. No preferences for font size, number of articles per source, refresh interval, etc.
- Files: `lib/main.dart` (lines 1570-1583 for view mode only)
- Blocks: Personalization.
- Recommendation: Expand SharedPreferences to include user preferences with UI in settings.

**No Article Search in Settings/Saved Tab:**
- Problem: Search only works in main feed tab, not in saved articles tab.
- Files: `lib/main.dart` (search bar conditional at line 2258, filter logic at lines 1744-1752)
- Blocks: Finding saved articles by title/content.
- Recommendation: Extend search functionality to saved articles context.

## Test Coverage Gaps

**What's not tested:**
- RSS XML parsing logic (_parseRssXml in lib/main.dart lines 315-479)
- Date parsing from various RSS formats (_parseDate, _parseCustomDate methods)
- Image extraction from different RSS feed formats
- Card swipe interactions and state transitions
- Article save/read state management
- SharedPreferences persistence operations
- Connectivity change handling
- Update service version comparison and GitHub API integration
- Settings view interactions
- Dialog rendering (update dialog, confirm dialogs)
- Error states and offline mode behavior

**Files:**
- `lib/main.dart` (zero test coverage for 2935 lines of core logic)
- `lib/services/update_service.dart` (no tests)
- `lib/services/apk_downloader.dart` (no tests)
- `lib/widgets/update_dialog.dart` (no tests)

**Risk:**
- Refactoring can break features silently
- Edge case handling (malformed RSS, network errors, null data) is unverified
- UI state transitions not validated
- Data persistence bugs could go undetected

**Priority:**
- RSS parsing: High - core feature, complex logic
- Card swipe state: High - complex user interaction
- Article state sync: High - data integrity
- Update service: Medium - secondary feature
- Settings: Low - simple UI

---

*Concerns audit: 2026-02-11*
