import '../models/article.dart';
import '../services/worker_feed_service.dart';
import '../services/storage_service.dart';
import '../repositories/feed_repository.dart';
import '../utils/error_handler.dart';
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
  Future<Result<List<Article>>> fetchNewArticles() async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching new articles from Worker API');

      // Fetch from Worker API using injected service
      final newArticles = await _workerFeedService.fetchArticles();

      if (newArticles.isEmpty) {
        return Result.success([]);
      }

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
      final lowerQuery = query.toLowerCase();

      final filteredArticles = articles.where((a) =>
          a.title.toLowerCase().contains(lowerQuery) ||
          a.description.toLowerCase().contains(lowerQuery) ||
          a.sourceName.toLowerCase().contains(lowerQuery)
      ).toList();

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
      final allResult = await fetchAllArticles(forceRefresh: true);
      if (allResult.isFailure) {
        return Result.failure(allResult.error ?? 'Failed to fetch articles');
      }

      final articles = allResult.data ?? [];
      final index = articles.indexWhere((a) => a.id == article.id);

      if (index == -1) {
        return Result.failure('Article not found');
      }

      articles[index] = articles[index].copyWith(isRead: true);
      _cachedArticles = articles;
      await _storageService.saveArticles(articles);

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

      // Update article in main list
      final allResult = await fetchAllArticles(forceRefresh: true);
      if (allResult.isSuccess) {
        final articles = allResult.data ?? [];
        final index = articles.indexWhere((a) => a.id == article.id);

        if (index != -1) {
          articles[index] = updatedArticle;
          _cachedArticles = articles;
          await _storageService.saveArticles(articles);
        }
      }

      // Update saved articles list
      final savedResult = await fetchSavedArticles();
      if (savedResult.isFailure) {
        return Result.failure(savedResult.error ?? 'Failed to fetch saved articles');
      }

      final savedArticles = savedResult.data ?? [];
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
