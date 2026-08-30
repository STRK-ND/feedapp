import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/filter_params.dart';
import '../services/worker_feed_service.dart';
import '../services/client_feed_service.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../utils/error_handler.dart';
import '../di/service_locator.dart';

/// Repository for managing article data access
/// Uses dependency injection for testability
class ArticleRepository {
  final StorageService _storageService;
  final WorkerFeedService _workerFeedService;
  // Nullable by design: older service graphs (and hand-built test graphs)
  // may not register these. Custom-source merging degrades to a no-op.
  final ClientFeedService? _clientFeedService;
  final SettingsService? _settingsService;

  ArticleRepository({
    StorageService? storageService,
    WorkerFeedService? workerFeedService,
    ClientFeedService? clientFeedService,
    SettingsService? settingsService,
  }) : _storageService = storageService ?? getIt<StorageService>(),
       _workerFeedService = workerFeedService ?? getIt<WorkerFeedService>(),
       _clientFeedService =
           clientFeedService ??
           (getIt.isRegistered<ClientFeedService>()
               ? getIt<ClientFeedService>()
               : null),
       _settingsService =
           settingsService ??
           (getIt.isRegistered<SettingsService>()
               ? getIt<SettingsService>()
               : null);

  // Cache for articles to avoid repeated storage reads
  List<Article>? _cachedArticles;
  List<Article>? _cachedSavedArticles;

  /// Clear the internal cache
  void clearCache() {
    _cachedArticles = null;
    _cachedSavedArticles = null;
  }

  /// Mirror the feed screen's authoritative in-memory lists into the cache.
  ///
  /// The feed screen mutates article read/save state in place and persists
  /// straight to storage (bypassing repository mutation methods), so the
  /// cache would otherwise drift — and the next refresh merge would revert
  /// the user's state. Push the source-of-truth lists in on every mutation.
  void syncFrom(List<Article> articles, List<Article> savedArticles) {
    _cachedArticles = List.of(articles);
    _cachedSavedArticles = List.of(savedArticles);
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
      debugPrint(
        '[Repository] Retrieved ${articles.length} articles from storage',
      );

      return Result.success(articles);
    } catch (e, stackTrace) {
      unawaited(
        ErrorHandler.logError(
          'Failed to fetch all articles',
          error: e,
          stackTrace: stackTrace,
        ),
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch new articles from Worker API and merge with existing.
  ///
  /// Delta strategy: when the local cache is non-empty, only articles
  /// strictly newer than the newest cached article (minus a 1h overlap
  /// guard for clock skew / late-published items) are requested via the
  /// `since` param — typically a few KB instead of the full feed. A full
  /// fetch happens when the cache is empty. Dedupe by id protects the
  /// overlap window either way.
  Future<Result<List<Article>>> fetchNewArticles() async {
    try {
      debugPrint('[Repository] Fetching new articles from Worker API');

      // Existing cache first: it defines the delta watermark.
      final existingResult = await fetchAllArticles();
      if (existingResult.isFailure) {
        return existingResult;
      }
      final existingArticles = existingResult.data ?? [];

      DateTime? watermark;
      if (existingArticles.isNotEmpty) {
        var maxDate = existingArticles.first.pubDate;
        for (final a in existingArticles) {
          if (a.pubDate.isAfter(maxDate)) maxDate = a.pubDate;
        }
        // Overlap window absorbs minor clock skew between worker and client.
        watermark = maxDate.subtract(const Duration(hours: 1));
      }

      // Fetch pages until exhausted (bounded at 5 pages / 250 articles).
      final workerArticles = <Article>[];
      int page = 1;
      bool hasMore = true;

      while (hasMore && page <= 5) {
        final response = await _workerFeedService.fetchArticles(
          params: FilterParams(
            page: page,
            pageSize: 50,
            since: watermark,
          ),
        );

        workerArticles.addAll(response.items);
        hasMore = response.hasMore;
        page++;

        if (response.items.isEmpty) break;
      }

      // User-added feeds are fetched client-side every refresh (capped per
      // source) — the worker doesn't know about them.
      final customArticles = await _fetchCustomSourceArticles();

      if (workerArticles.isEmpty && customArticles.isEmpty) {
        return Result.success(existingArticles);
      }

      final existingIds = existingArticles.map((a) => a.id).toSet();

      // Filter out duplicates
      final articlesToAdd = [
        ...workerArticles,
        ...customArticles,
      ]
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

      debugPrint(
        '[Repository] Added ${articlesToAdd.length} new articles. Total: ${mergedArticles.length}',
      );

      return Result.success(mergedArticles);
    } catch (e, stackTrace) {
      unawaited(
        ErrorHandler.logError(
          'Failed to fetch new articles',
          error: e,
          stackTrace: stackTrace,
        ),
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch every subscribed custom feed in parallel. One failing source
  /// never fails the refresh — it's skipped and retried next cycle.
  /// Any unexpected failure (e.g. storage unavailable in tests) degrades
  /// to "no custom articles" rather than breaking the worker merge.
  Future<List<Article>> _fetchCustomSourceArticles() async {
    final clientFeedService = _clientFeedService;
    final settingsService = _settingsService;
    if (clientFeedService == null || settingsService == null) return [];
    try {
      final customs = await settingsService.getCustomSources();
      final subscribed = await settingsService.getSubscribedSourceIds();
      final active = customs
          .where((s) => subscribed.isEmpty || subscribed.contains(s.id))
          .toList();
      if (active.isEmpty) return [];

      final results = await Future.wait(
        active.map(
          (s) => clientFeedService
              .fetchSourceArticles(s)
              .catchError((Object _) => <Article>[]),
        ),
      );
      return results.expand((list) => list).toList();
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Custom source fetch skipped', error: e),
      );
      return [];
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
      unawaited(
        ErrorHandler.logError(
          'Failed to fetch saved articles',
          error: e,
          stackTrace: stackTrace,
        ),
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
      final articles = _cachedArticles;
      if (articles != null) {
        final index = articles.indexWhere((a) => a.id == article.id);
        if (index != -1) {
          final updatedArticles = List<Article>.from(articles);
          updatedArticles[index] = updatedArticle;
          _cachedArticles = updatedArticles;
          // Row-level persist: a save touches one feed row, not the cache.
          await _storageService.saveArticle(updatedArticle);
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
        // Row-level persist: one saved row insert/update or delete.
        if (isSaved) {
          await _storageService.saveSavedArticle(updatedArticle);
        } else {
          await _storageService.removeSavedArticle(article.id);
        }
      }

      return Result.success(null);
    } catch (e, stackTrace) {
      unawaited(
        ErrorHandler.logError(
          'Failed to toggle save status',
          error: e,
          stackTrace: stackTrace,
        ),
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
      final flipped = <Article>[];
      final updated = <Article>[];
      for (final a in articles) {
        if (!a.isRead) {
          previousReadState[a.id] = false; // value irrelevant; key matters
          final read = a.copyWith(isRead: true);
          updated.add(read);
          flipped.add(read);
        } else {
          updated.add(a);
        }
      }

      if (flipped.isEmpty) {
        return Result.success(<String, bool>{});
      }

      _cachedArticles = updated;
      // Row-level persist: rewrite only the flipped rows, not the whole cache.
      await _storageService.upsertArticles(flipped);

      debugPrint(
        '[Repository] Marked all read. Flipped ${flipped.length} article(s).',
      );
      return Result.success(previousReadState);
    } catch (e, stackTrace) {
      unawaited(
        ErrorHandler.logError(
          'Failed to mark all as read',
          error: e,
          stackTrace: stackTrace,
        ),
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

      final flipped = <Article>[];
      final updated = <Article>[];
      for (final a in articles) {
        if (ids.contains(a.id) && a.isRead) {
          final unread = a.copyWith(isRead: false);
          updated.add(unread);
          flipped.add(unread);
        } else {
          updated.add(a);
        }
      }

      _cachedArticles = updated;
      // Row-level persist: only rows that actually flipped back.
      await _storageService.upsertArticles(flipped);

      debugPrint(
        '[Repository] Restored ${flipped.length} article(s) to unread.',
      );
      return Result.success(null);
    } catch (e, stackTrace) {
      unawaited(
        ErrorHandler.logError(
          'Failed to restore read state',
          error: e,
          stackTrace: stackTrace,
        ),
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
}
