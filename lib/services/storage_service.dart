import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/article.dart';
import '../utils/error_handler.dart';
import 'feed_database.dart';
import 'sync_hooks.dart';

/// Storage service for managing persistent data.
///
/// Article lists live in SQLite ([FeedDatabase]); small preferences
/// (last refresh) stay in secure storage. The public API is
/// unchanged from the blob-storage era so no call sites moved.
class StorageService {
  final FlutterSecureStorage _storage;
  final FeedDatabase _database;

  /// Cloud-sync push hook. Assigned by the service locator after the sync
  /// service exists (avoids get-it circular construction). Null in tests
  /// and when signed out.
  SyncHooks? syncHooks;

  // Canonical storage keys — keep all reads/writes/deletes on these
  // constants so a targeted clear can never drift from what was written.
  static const String kArticlesKey = 'articles'; // legacy blob location
  static const String kSavedArticlesKey = 'savedArticles'; // legacy blob
  static const String kLastRefreshKey = 'lastRefresh';

  StorageService({FlutterSecureStorage? storage, FeedDatabase? database})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions()),
      _database = database ?? FeedDatabase();

  /// Save articles list (public data)
  Future<void> saveArticles(List<Article> articles) async {
    try {
      await _database.saveArticles(articles);
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to save articles', error: e));
    }
  }

  /// Load articles list
  Future<List<Article>> loadArticles() async {
    try {
      await _migrateLegacyBlobsIfNeeded();
      return await _database.loadArticles();
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to load articles', error: e));
      return [];
    }
  }

  /// Save saved articles
  Future<void> saveSavedArticles(List<Article> articles) async {
    try {
      await _database.saveSavedArticles(articles);
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to save saved articles', error: e),
      );
    }
  }

  /// Load saved articles
  Future<List<Article>> loadSavedArticles() async {
    try {
      return await _database.loadSavedArticles();
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to load saved articles', error: e),
      );
      return [];
    }
  }

  /// Persist one article row — triage hot path (single-row write instead
  /// of a full-table rewrite on every read/save flag change).
  Future<void> saveArticle(Article article) async {
    try {
      await _database.upsertArticle(article);
      syncHooks?.onArticleMutated(article);
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to save article', error: e));
    }
  }

  /// Upsert several article rows in one transaction — bulk flag flips
  /// (mark-all-read / undo) persist only the rows that changed.
  Future<void> upsertArticles(List<Article> articles) async {
    try {
      await _database.upsertArticles(articles);
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to save article rows', error: e));
    }
  }

  /// Persist one row in the saved list (front-insert or payload refresh).
  Future<void> saveSavedArticle(Article article) async {
    try {
      await _database.upsertSavedArticle(article);
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to save saved article', error: e),
      );
    }
  }

  /// Remove one article from the saved list by id: flips the article row
  /// to unsaved (so the flag survives restarts) and pushes both a payload
  /// update and a deletion tombstone to the cloud mirror.
  Future<void> removeSavedArticle(String id) async {
    try {
      final updated = await _database.markUnsaved(id);
      syncHooks?.onSavedArticleRemoved(id);
      if (updated != null) syncHooks?.onArticleMutated(updated);
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to remove saved article', error: e),
      );
    }
  }

  /// Cloud-sync pull helper: apply a remote deletion tombstone locally
  /// (payload flag + saved row) without firing push hooks — pulls must
  /// not echo back to the cloud.
  Future<void> unsaveArticleLocally(String id) async {
    try {
      await _database.markUnsaved(id);
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to unsave article locally', error: e),
      );
    }
  }

  /// Cloud-sync pull helper: updated_at per article id, used to decide
  /// which local rows are newer than the cloud mirror.
  Future<Map<String, int>> loadArticleTimestamps() async {
    try {
      return await _database.loadArticleTimestamps();
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to load article timestamps', error: e),
      );
      return {};
    }
  }

  /// Decode a stored article JSON array, skipping (not discarding) any
  /// record that fails to parse. Used by the one-time legacy-blob
  /// migration; a corrupt record never wipes the whole set (data-layer L8).
  List<Article> _decodeArticleList(String jsonString, {required String key}) {
    final List<dynamic> decoded = json.decode(jsonString);
    final articles = <Article>[];
    for (final item in decoded) {
      try {
        articles.add(Article.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        unawaited(
          ErrorHandler.logError(
            'Failed to parse an article record ($key)',
            error: e,
          ),
        );
      }
    }
    return articles;
  }

  // One-time import of the pre-sqlite blobs. Runs at most once per
  // install; guarded by a marker key in secure storage.
  static const String kMigratedKey = 'articles_migrated_sqlite_v1';
  bool _migrationChecked = false;

  Future<void> _migrateLegacyBlobsIfNeeded() async {
    if (_migrationChecked) return;
    _migrationChecked = true;
    try {
      if (await _storage.read(key: kMigratedKey) == '1') return;

      final legacyArticles = _storage.read(key: kArticlesKey);
      final legacySaved = _storage.read(key: kSavedArticlesKey);
      final articlesJson = await legacyArticles;
      final savedJson = await legacySaved;

      if (articlesJson != null) {
        await _database.saveArticles(_decodeArticleList(articlesJson, key: kArticlesKey));
      }
      if (savedJson != null) {
        await _database.saveSavedArticles(
          _decodeArticleList(savedJson, key: kSavedArticlesKey),
        );
      }
      await _storage.write(key: kMigratedKey, value: '1');
      // Blobs are now redundant; drop them.
      await _storage.delete(key: kArticlesKey);
      await _storage.delete(key: kSavedArticlesKey);
    } catch (e) {
      // Migration failure must not break the app: next launch retries.
      _migrationChecked = false;
      unawaited(ErrorHandler.logError('Legacy storage migration failed', error: e));
    }
  }

  /// Save last refresh time
  Future<void> saveLastRefreshTime(DateTime? time) async {
    try {
      if (time == null) {
        await _storage.delete(key: kLastRefreshKey);
      } else {
        await _storage.write(
          key: kLastRefreshKey,
          value: time.toIso8601String(),
        );
      }
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to save last refresh time', error: e),
      );
    }
  }

  /// Load last refresh time
  Future<DateTime?> loadLastRefreshTime() async {
    try {
      final timeString = await _storage.read(key: kLastRefreshKey);
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to load last refresh time', error: e),
      );
      return null;
    }
  }

  /// Clear only the feed cache — the fetched article list and the last
  /// refresh timestamp. Saved articles and any other keys are
  /// left untouched: "Clear cache" in Settings must never destroy user data.
  Future<void> clearFeedCache() async {
    try {
      await _database.clearFeedCache();
      // Legacy blob (pre-migration installs) + refresh stamp.
      await _storage.delete(key: kArticlesKey);
      await _storage.delete(key: kLastRefreshKey);
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to clear feed cache', error: e));
    }
  }

  /// Clear all storage data
  Future<void> clearAll() async {
    try {
      await _database.clearAll();
      await _storage.deleteAll();
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to clear storage', error: e));
    }
  }
}
