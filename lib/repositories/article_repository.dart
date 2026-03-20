import '../models/article.dart';
import '../models/filter_params.dart';
import '../services/worker_feed_service.dart';
import '../services/storage_service.dart';
import '../repositories/feed_repository.dart';
import '../utils/error_handler.dart';
import '../utils/helpers.dart';
import '../di/service_locator.dart';

/// Repository for managing article data access
/// Uses dependency injection for testability
class ArticleRepository {
  final StorageService _storageService;
  final FeedRepository _feedRepository;
  final WorkerFeedService _workerFeedService;

  ArticleRepository({
    StorageService? storageService,
    FeedRepository? feedRepository,
    WorkerFeedService? workerFeedService,
  })  : _storageService = storageService ?? getIt<StorageService>(),
        _feedRepository = feedRepository ?? getIt<FeedRepository>(),
        _workerFeedService = workerFeedService ?? getIt<WorkerFeedService>();

  // Cache for articles to avoid repeated storage reads
  List<Article>? _cachedArticles;
  List<Article>? _cachedSavedArticles;

  /// Clear the internal cache
  void clearCache() {
    _cachedArticles = null;
    _cachedSavedArticles = null;
  }

  /// Fetch all articles from storage
  Future<Result<List<Article>>> fetchAllArticles({bool forceRefresh = false}) async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching all articles');

      final cached = _cachedArticles;
      if (!forceRefresh && cached != null) {
        return Result.success(cached);
      }

      final articles = await _storageService.loadArticles();
      _cachedArticles = articles;

      ErrorHandler.logError(
        'Retrieved ${articles.length} articles from storage',
        severity: ErrorSeverity.low,
      );

      return Result.success(articles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch all articles',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch new articles from Worker API and merge with existing
  /// Now fetches all pages from the paginated API
  Future<Result<List<Article>>> fetchNewArticles() async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching new articles from Worker API');

      // Fetch all pages
      final allArticles = <Article>[];
      int page = 1;
      bool hasMore = true;

      while (hasMore && page <= 5) {  // Limit to 5 pages (250 articles max)
        final response = await _workerFeedService.fetchArticles(
          params: FilterParams(page: page, pageSize: 50),
        );

        allArticles.addAll(response.items);
        hasMore = response.hasMore;
        page++;

        if (response.items.isEmpty) break;
      }

      if (allArticles.isEmpty) {
        return Result.success([]);
      }

      final newArticles = allArticles;

      // Get existing articles
      final existingResult = await fetchAllArticles();
      if (existingResult.isFailure) {
        return existingResult;
      }

      final existingArticles = existingResult.data ?? [];
      final existingIds = existingArticles.map((a) => a.id).toSet();

      // Filter out duplicates
      final articlesToAdd = newArticles.where((a) => !existingIds.contains(a.id)).toList();

      if (articlesToAdd.isEmpty) {
        ErrorHandler.logError(
          'No new articles found',
          severity: ErrorSeverity.low,
        );
        return Result.success(existingArticles);
      }

      // Merge and sort
      final mergedArticles = [...existingArticles, ...articlesToAdd];
      mergedArticles.sort((a, b) => b.pubDate.compareTo(a.pubDate));

      // Update cache and save
      _cachedArticles = mergedArticles;
      await _storageService.saveArticles(mergedArticles);

      ErrorHandler.logError(
        'Added ${articlesToAdd.length} new articles. Total: ${mergedArticles.length}',
        severity: ErrorSeverity.low,
      );

      return Result.success(mergedArticles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch new articles',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch articles from a specific source
  Future<Result<List<Article>>> fetchArticlesFromSource(String sourceId) async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching articles from source: $sourceId');

      final allResult = await fetchAllArticles();
      if (allResult.isFailure) {
        return allResult;
      }

      final articles = allResult.data ?? [];
      final filteredArticles = articles.where((a) => a.sourceId == sourceId).toList();

      return Result.success(filteredArticles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch articles from source $sourceId',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch saved articles
  Future<Result<List<Article>>> fetchSavedArticles() async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching saved articles');

      final cached = _cachedSavedArticles;
      if (cached != null) {
        return Result.success(cached);
      }

      final articles = await _storageService.loadSavedArticles();
      _cachedSavedArticles = articles;

      return Result.success(articles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch saved articles',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Search articles by query across title, description, and source name
  Future<Result<List<Article>>> searchArticles(String query) async {
    try {
      if (query.isEmpty) {
        return await fetchAllArticles();
      }

      ErrorHandlerExtensions.logInfo('Searching articles with query: $query');

final allResult = await fetchAllArticles();
      if (allResult.isFailure) {
        return allResult;
      }

      final articles = allResult.data ?? [];
      final filteredArticles = Helpers.filterArticlesByQuery(articles, query);

      return Result.success(filteredArticles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to search articles',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Filter articles by category using source metadata from Worker response
  Future<Result<List<Article>>> filterByCategory(String category) async {
    try {
      if (category.isEmpty || category == 'All') {
        return await fetchAllArticles();
      }

      ErrorHandlerExtensions.logInfo('Filtering articles by category: $category');

      // Get all articles
      final allResult = await fetchAllArticles();
      if (allResult.isFailure) {
        return allResult;
      }

      final articles = allResult.data ?? [];
      // Filter by sourceCategory from article metadata (provided by Worker)
      final filteredArticles = articles.where((a) => a.sourceCategory == category).toList();

      return Result.success(filteredArticles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to filter articles by category',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Filter unread articles
  Future<Result<List<Article>>> filterUnread() async {
    try {
      ErrorHandlerExtensions.logInfo('Filtering unread articles');

      final allResult = await fetchAllArticles();
      if (allResult.isFailure) {
        return allResult;
      }

      final articles = allResult.data ?? [];
      final unreadArticles = articles.where((a) => !a.isRead).toList();

      return Result.success(unreadArticles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to filter unread articles',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Mark an article as read
  Future<Result<void>> markAsRead(Article article) async {
    try {
      // Work with cached data directly - avoid full refresh
      var articles = _cachedArticles;
      if (articles == null) {
        final allResult = await fetchAllArticles();
        if (allResult.isFailure) {
          return Result.failure(allResult.error ?? 'Failed to fetch articles');
        }
        articles = allResult.data ?? [];
      }

      final index = articles.indexWhere((a) => a.id == article.id);
      if (index == -1) {
        return Result.failure('Article not found');
      }

      // Create updated list with immutable copy
      final updatedArticles = List<Article>.from(articles);
      updatedArticles[index] = updatedArticles[index].copyWith(isRead: true);

      // Update cache and persist
      _cachedArticles = updatedArticles;
      await _storageService.saveArticles(updatedArticles);

      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to mark article as read',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Toggle save status for an article
  Future<Result<void>> toggleSave(Article article, {bool isSaved = false}) async {
    try {
      // Create updated article with new save state
      final updatedArticle = article.copyWith(isSaved: isSaved);

      // Update main articles cache directly without full refresh
      var articles = _cachedArticles;
      if (articles != null) {
        final index = articles.indexWhere((a) => a.id == article.id);
        if (index != -1) {
          final updatedArticles = List<Article>.from(articles);
          updatedArticles[index] = updatedArticle;
          _cachedArticles = updatedArticles;
          await _storageService.saveArticles(updatedArticles);
        }
      }

      // Update saved articles cache directly
      final savedArticles = _cachedSavedArticles;
      if (savedArticles != null) {
        final updatedSavedArticles = List<Article>.from(savedArticles);

        if (isSaved) {
          // Add to saved if not already there
          if (!updatedSavedArticles.any((a) => a.id == article.id)) {
            updatedSavedArticles.insert(0, updatedArticle);
          }
        } else {
          // Remove from saved
          updatedSavedArticles.removeWhere((a) => a.id == article.id);
        }

        _cachedSavedArticles = updatedSavedArticles;
        await _storageService.saveSavedArticles(updatedSavedArticles);
      }

      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to toggle save status',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Remove an article from the main list
  Future<Result<void>> removeArticle(String articleId) async {
    try {
      final allResult = await fetchAllArticles(forceRefresh: true);
      if (allResult.isFailure) {
        return Result.failure(allResult.error ?? 'Failed to fetch articles');
      }

      final articles = allResult.data ?? [];
      final remainingArticles = articles.where((a) => a.id != articleId).toList();

      _cachedArticles = remainingArticles;
      await _storageService.saveArticles(remainingArticles);

      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to remove article',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get unread count
  Future<Result<int>> getUnreadCount() async {
    try {
      final unreadResult = await filterUnread();
      if (unreadResult.isFailure) {
        return Result.failure(unreadResult.error ?? 'Failed to get unread articles');
      }

      return Result.success(unreadResult.data?.length ?? 0);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get unread count',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch articles with specific filter parameters
  Future<Result<List<Article>>> fetchArticlesWithFilters(FilterParams params) async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching articles with filters');

      final response = await _workerFeedService.fetchArticles(params: params);

      return Result.success(response.items);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch articles with filters',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch available sources from Worker
  Future<Result<List<Map<String, dynamic>>>> fetchAvailableSources() async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching available sources');

      final sources = await _workerFeedService.fetchSources();
      return Result.success(sources);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch sources',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch full article content
  Future<Result<Map<String, dynamic>?>> fetchArticleFullContent(String articleUrl) async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching full content for article');

      final content = await _workerFeedService.fetchFullContent(articleUrl);

      if (content == null) {
        return Result.failure('Failed to fetch full content');
      }

      return Result.success(content);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch full content',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
}

/// Extension on ErrorHandler for logging shortcuts
extension ErrorHandlerExtensions on ErrorHandler {
  /// Log info message
  static void logInfo(String message) {
    ErrorHandler.logError(
      message,
      severity: ErrorSeverity.low,
    );
  }

  /// Log warning message
  static void logWarning(String message) {
    ErrorHandler.logError(
      message,
      severity: ErrorSeverity.medium,
    );
  }
}
