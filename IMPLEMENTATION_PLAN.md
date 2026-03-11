# Architecture Implementation Plan

## Completed Tasks:

### 1. ✅ Fixed Dependency Injection (lib/di/service_locator.dart)
- Registered all services as singletons: StorageService, CacheManager, SettingsService
- Registered RssFeedService, ArticleContentService, WorkerFeedService as injectable singletons
- Removed comment about static classes
- Fixed repository registrations to use proper DI

### 2. ✅ Converted Static Services to Injectable
- **lib/services/rss_feed_service.dart**:
  - Removed private constructor _()
  - Added _httpClient dependency with constructor injection
  - Converted all static methods to instance methods

- **lib/services/article_content_service.dart**:
  - Removed private constructor _()
  - Added _httpClient dependency
  - Converted all static methods to instance methods
  - Made _domainSelectors non-static

- **lib/services/worker_feed_service.dart**:
  - Removed private constructor _()
  - Added _httpClient dependency
  - Converted all static methods to instance methods

### 3. ✅ Updated FeedRepository for DI (lib/repositories/feed_repository.dart)
- Added RssFeedService dependency via constructor
- Replaced all RssFeedService.predefinedSources with _rssFeedService.predefinedSources
- Replaced RssFeedService.getSourceById with _rssFeedService.getSourceById
- Removed const constructor, now uses proper DI

### 4. 🔄 In Progress: Update ArticleRepository for DI (lib/repositories/article_repository.dart)
- Need to:
  - Add WorkerFeedService dependency
  - Replace WorkerFeedService.fetchArticles() with instance call
  - Remove getStorage() helper and const FeedRepository()
  - Use getIt for dependency resolution

### 5. ⏳ Create FeedProvider (lib/providers/feed_provider.dart) - NEXT
- Create new ChangeNotifier-based provider
- Move all state from FeedScreen: _articles, _savedArticles, _displayedArticles, _selectedFilter, _viewMode, _isLoading, _errorMessage
- Expose methods: loadArticles, fetchNewArticles, searchArticles, filterByCategory, toggleSave, markAsRead

### 6. ⏳ Refactor FeedScreen (lib/screens/feed_screen.dart)
- Convert from StatefulWidget to StatelessWidget
- Use FeedProvider via context.watch/select
- Remove all direct repository instantiation
- Update handleSave callback to use FeedProvider

### 7. ⏳ Make Article Model Immutable (lib/models/article.dart)
- Change isRead, isSaved, fetchedFullContent from "bool/String?" to "final bool/String?"
- Update ArticleRepository to use copyWith instead of direct mutation
- Update any widget code that mutates articles

### 8. ⏳ Update CI/CD (.github/workflows/build.yml)
- Add flutter analyze step
- Add flutter test step (or placeholder)
- Add caching for pub dependencies
- Add build number increment

## Next Steps:

1. Complete ArticleRepository DI update
2. Create FeedProvider
3. Refactor FeedScreen
4. Update Article model and usages
5. Update CI/CD workflow
6. Run flutter analyze to verify all changes

## Known Issues to Fix:

1. FeedScreen still creating new ArticleRepository() directly - needs to use Provider
2. ExpandedArticleCard directly calls ArticleContentService - should use repository or be provided
3. UpdateService, VersionProvider, ApkDownloader are still static - consider making injectable
4. Need to make sure getIt setup runs before any service access
