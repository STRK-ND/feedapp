import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/article.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

/// Storage service for managing persistent data
class StorageService {
  final FlutterSecureStorage _storage;

  StorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  /// Save articles list (public data)
  Future<void> saveArticles(List<Article> articles) async {
    try {
      // Enforce article limit
      final limitedArticles = _enforceArticleLimit(articles);

      final jsonData = json.encode(
        limitedArticles.map((a) => a.toJson()).toList(),
      );
      await _storage.write(key: 'articles', value: jsonData);
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to save articles', error: e));
    }
  }

  /// Load articles list
  Future<List<Article>> loadArticles() async {
    try {
      final jsonString = await _storage.read(key: 'articles');
      if (jsonString == null) return [];

      final List<dynamic> decoded = json.decode(jsonString);
      return decoded
          .map((json) => Article.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to load articles', error: e));
      return [];
    }
  }

  /// Save saved articles
  Future<void> saveSavedArticles(List<Article> articles) async {
    try {
      final jsonData = json.encode(articles.map((a) => a.toJson()).toList());
      await _storage.write(key: 'savedArticles', value: jsonData);
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to save saved articles', error: e),
      );
    }
  }

  /// Load saved articles
  Future<List<Article>> loadSavedArticles() async {
    try {
      final jsonString = await _storage.read(key: 'savedArticles');
      if (jsonString == null) return [];

      final List<dynamic> decoded = json.decode(jsonString);
      return decoded
          .map((json) => Article.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to load saved articles', error: e),
      );
      return [];
    }
  }

  /// Save last refresh time
  Future<void> saveLastRefreshTime(DateTime? time) async {
    try {
      if (time == null) {
        await _storage.delete(key: 'lastRefresh');
      } else {
        await _storage.write(key: 'lastRefresh', value: time.toIso8601String());
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
      final timeString = await _storage.read(key: 'lastRefresh');
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      unawaited(
        ErrorHandler.logError('Failed to load last refresh time', error: e),
      );
      return null;
    }
  }

  /// Save view mode preference
  Future<void> saveViewMode(String viewMode) async {
    try {
      await _storage.write(key: 'viewMode', value: viewMode);
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to save view mode', error: e));
    }
  }

  /// Load view mode preference
  Future<String?> loadViewMode() async {
    try {
      return await _storage.read(key: 'viewMode');
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to load view mode', error: e));
      return null;
    }
  }

  /// Clear all storage data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to clear storage', error: e));
    }
  }

  /// Enforce article limit by removing oldest articles
  List<Article> _enforceArticleLimit(List<Article> articles) {
    if (articles.length <= AppConfig.maxCachedArticles) {
      return articles;
    }

    // Sort by date (newest first), then by id for deterministic ordering
    final sorted = List<Article>.from(articles);
    sorted.sort((a, b) {
      final dateCompare = b.pubDate.compareTo(a.pubDate);
      if (dateCompare != 0) return dateCompare;
      return a.id.compareTo(b.id);
    });
    return sorted.take(AppConfig.maxCachedArticles).toList();
  }
}
