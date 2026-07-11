import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/filter_params.dart';
import '../services/worker_feed_service.dart';
import '../services/storage_service.dart';
import '../utils/error_handler.dart';
import '../di/service_locator.dart';

/// Repository for managing article data access
/// Uses dependency injection for testability
class ArticleRepository {
  final StorageService _storageService;
  final WorkerFeedService _workerFeedService;

  ArticleRepository({
    StorageService? storageService,
    WorkerFeedService? workerFeedService,
  }) : _storageService = storageService ?? getIt<StorageService>(),
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
  Future<Result<List<Article>>> fetchAllArticles({
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint('[Repository] Fetching all articles');

      final cached = _cachedArticles;
      if (!forceRefresh && cached != null) {
        return Result.success(cached);
      }

      final articles = await _storageService.loadArticles();
      _cachedArticles = articles;

      // Use debugPrint for success/info messages — ErrorHandler is for actual errors
      debugPrint('[Repository] Retrieved ${articles.length} articles from storage');

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
      debugPrint('[Repository] Fetching new articles from Worker API');

      // Fetch all pages
      final allArticles = <Article>[];
      int page = 1;
      bool hasMore = true;

      while (hasMore && page <= 5) {
        // Limit to 5 pages (250 articles max)
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
      final articlesToAdd = newArticles
          .where((a) => !existingIds.contains(a.id))
          .toList();

      if (articlesToAdd.isEmpty) {
        debugPrint('[Repository] No new articles found');
        return Result.success(existingArticles);
      }

      // Merge and sort
      final mergedArticles = [...existingArticles, ...articlesToAdd];
      mergedArticles.sort((a, b) => b.pubDate.compareTo(a.pubDate));

      // Update cache and save
      _cachedArticles = mergedArticles;
      await _storageService.saveArticles(mergedArticles);

      debugPrint('[Repository] Added ${articlesToAdd.length} new articles. Total: ${mergedArticles.length}');

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

  /// Fetch saved articles
  Future<Result<List<Article>>> fetchSavedArticles() async {
    try {
      debugPrint('[Repository] Fetching saved articles');

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

  /// Toggle save status for an article
  Future<Result<void>> toggleSave(
    Article article, {
    bool isSaved = false,
  }) async {
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
          }        } else {
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

  /// Mark every currently-unread, not-yet-saved article as read.
  ///
  /// Returns the **previous** read state per article as `Map<String,
  /// bool>` keyed by id — only articles whose isRead=false at the
  /// moment of the call are included, so undo restores exactly the
  /// set that flipped. Articles that were already-read stay read,
  /// even after undo.
  Future<Result<Map<String, bool>>> markAllAsRead() async {
    try {
      final articles = _cachedArticles;
      if (articles == null) {
        return Result.success(<String, bool>{});
      }

      final previousReadState = <String, bool>{};
      var touched = 0;
      final updated = <Article>[];
      for (final a in articles) {
        if (!a.isRead) {
          previousReadState[a.id] = false; // value irrelevant; key matters
          updated.add(a.copyWith(isRead: true));
          touched++;
        } else {
          updated.add(a);
        }
      }

      if (touched == 0) {
        return Result.success(<String, bool>{});
      }

      _cachedArticles = updated;
      await _storageService.saveArticles(updated);

      debugPrint(
        '[Repository] Marked all read. Flipped $touched article(s).',
      );
      return Result.success(previousReadState);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to mark all as read',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Restore a previously-flipped set of reads back to unread.
  ///
  /// Pass the exact `Map<String, bool>` returned from `markAllAsRead`.
  /// Articles whose ids are in the map are reset to `isRead=false`;
  /// everything else is left untouched.
  Future<Result<void>> restoreReadState(Map<String, bool> snapshot) async {
    try {
      final articles = _cachedArticles;
      if (articles == null) {
        return Result.success(null);
      }
      final ids = snapshot.keys.toSet();
      if (ids.isEmpty) return Result.success(null);

      final updated = <Article>[];
      for (final a in articles) {
        if (ids.contains(a.id)) {
          updated.add(a.copyWith(isRead: false));
        } else {
          updated.add(a);
        }
      }

      _cachedArticles = updated;
      await _storageService.saveArticles(updated);

      debugPrint(
        '[Repository] Restored ${ids.length} article(s) to unread.',
      );
      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to restore read state',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

}
