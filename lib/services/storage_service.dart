import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/article.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import 'key_value_storage.dart';

/// Storage service for managing persistent data
class StorageService {
  final KeyValueStorage _storage;

  StorageService({KeyValueStorage? storage})
      : _storage = storage ?? _FlutterSecureStorageAdapter();

  /// Save articles list (public data)
  Future<void> saveArticles(List<Article> articles) async {
    try {
      // Enforce article limit
      final limitedArticles = _enforceArticleLimit(articles);

      final jsonData = json.encode(
        limitedArticles.map((a) => a.toJson()).toList(),
      );
      await _storage.write('articles', jsonData);
    } catch (e) {
      ErrorHandler.logError('Failed to save articles', error: e);
    }
  }

  /// Load articles list
  Future<List<Article>> loadArticles() async {
    try {
      final jsonString = await _storage.read('articles');
      if (jsonString == null) return [];

      final List<dynamic> decoded = json.decode(jsonString);
      return decoded
          .map((json) => Article.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      ErrorHandler.logError('Failed to load articles', error: e);
      return [];
    }
  }

  /// Save saved articles
  Future<void> saveSavedArticles(List<Article> articles) async {
    try {
      final jsonData = json.encode(articles.map((a) => a.toJson()).toList());
      await _storage.write('savedArticles', jsonData);
    } catch (e) {
      ErrorHandler.logError('Failed to save saved articles', error: e);
    }
  }

  /// Load saved articles
  Future<List<Article>> loadSavedArticles() async {
    try {
      final jsonString = await _storage.read('savedArticles');
      if (jsonString == null) return [];

      final List<dynamic> decoded = json.decode(jsonString);
      return decoded
          .map((json) => Article.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      ErrorHandler.logError('Failed to load saved articles', error: e);
      return [];
    }
  }

  /// Save last refresh time
  Future<void> saveLastRefreshTime(DateTime? time) async {
    try {
      if (time == null) {
        await _storage.delete('lastRefresh');
      } else {
        await _storage.write('lastRefresh', time.toIso8601String());
      }
    } catch (e) {
      ErrorHandler.logError('Failed to save last refresh time', error: e);
    }
  }

  /// Load last refresh time
  Future<DateTime?> loadLastRefreshTime() async {
    try {
      final timeString = await _storage.read('lastRefresh');
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      ErrorHandler.logError('Failed to load last refresh time', error: e);
      return null;
    }
  }

  /// Save view mode preference
  Future<void> saveViewMode(String viewMode) async {
    try {
      await _storage.write('viewMode', viewMode);
    } catch (e) {
      ErrorHandler.logError('Failed to save view mode', error: e);
    }
  }

  /// Load view mode preference
  Future<String?> loadViewMode() async {
    try {
      return await _storage.read('viewMode');
    } catch (e) {
      ErrorHandler.logError('Failed to load view mode', error: e);
      return null;
    }
  }

  /// Clear all storage data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      ErrorHandler.logError('Failed to clear storage', error: e);
    }
  }

  /// Enforce article limit by removing oldest articles
  List<Article> _enforceArticleLimit(List<Article> articles) {
    if (articles.length <= AppConfig.maxCachedArticles) {
      return articles;
    }

    // Sort by date (newest first) and take only max
    final sorted = List<Article>.from(articles);
    sorted.sort((a, b) => b.pubDate.compareTo(a.pubDate));
    return sorted.take(AppConfig.maxCachedArticles).toList();
  }
}

/// Adapter wrapping FlutterSecureStorage to KeyValueStorage interface
class _FlutterSecureStorageAdapter implements KeyValueStorage {
  final FlutterSecureStorage _delegate = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  @override
  Future<String?> read(String key) => _delegate.read(key: key);

  @override
  Future<void> write(String key, String? value) =>
      _delegate.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _delegate.delete(key: key);

  @override
  Future<void> deleteAll() => _delegate.deleteAll();
}
