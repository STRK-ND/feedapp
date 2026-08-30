import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:curatedfeeds/services/feed_database.dart';
import 'package:curatedfeeds/services/storage_service.dart';
import 'package:curatedfeeds/models/article.dart';

int _dbCounter = 0;

/// Fresh SQLite database per call. The ffi factory caches instances by
/// path, so ':memory:' alone would leak rows across tests — a unique
/// temp-file path guarantees isolation.
Future<Database> openMemoryDb() async {
  sqfliteFfiInit();
  final dir = await Directory.systemTemp.createTemp('curatedfeeds_test');
  return databaseFactoryFfi.openDatabase(
    '${dir.path}${Platform.pathSeparator}feed-${_dbCounter++}.db',
  );
}

Future<StorageService> makeService(MockFlutterSecureStorage storage) async {
  final db = await openMemoryDb();
  return StorageService(
    storage: storage,
    database: FeedDatabase(db: db),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    late StorageService service;
    late MockFlutterSecureStorage mockStorage;

    setUp(() async {
      mockStorage = MockFlutterSecureStorage();
      service = await makeService(mockStorage);
    });

    group('saveArticles / loadArticles', () {
      test('saves and loads articles roundtrip', () async {
        final articles = [
          _makeArticle(
            id: '1',
            title: 'Article 1',
            pubDate: DateTime.utc(2026, 1, 2),
          ),
          _makeArticle(
            id: '2',
            title: 'Article 2',
            pubDate: DateTime.utc(2026, 1, 1),
          ),
        ];

        await service.saveArticles(articles);
        final loaded = await service.loadArticles();

        expect(loaded.length, 2);
        // Newest first (pub_date DESC).
        expect(loaded[0].title, 'Article 1');
        expect(loaded[1].title, 'Article 2');
      });

      test('returns empty list when no articles saved', () async {
        final loaded = await service.loadArticles();
        expect(loaded, isEmpty);
      });

      test('overwrites existing articles on save', () async {
        await service.saveArticles([_makeArticle(id: '1', title: 'Old')]);
        await service.saveArticles([_makeArticle(id: '2', title: 'New')]);

        final loaded = await service.loadArticles();
        expect(loaded.length, 1);
        expect(loaded[0].title, 'New');
      });

      test('enforces article limit when saving, keeping newest', () async {
        final manyArticles = List.generate(
          1500,
          (i) => _makeArticle(
            id: '$i',
            title: 'Article $i',
            pubDate: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          ),
        );

        await service.saveArticles(manyArticles);
        final loaded = await service.loadArticles();

        expect(loaded.length, 1000); // AppConfig.maxCachedArticles
        // The oldest entries were dropped.
        expect(loaded.any((a) => a.id == '0'), isFalse);
        expect(loaded.any((a) => a.id == '1499'), isTrue);
      });
    });

    group('saveSavedArticles / loadSavedArticles', () {
      test('saves and loads saved articles roundtrip preserving order', () async {
        final articles = [
          _makeArticle(id: '1', title: 'Saved 1', isSaved: true),
          _makeArticle(id: '2', title: 'Saved 2', isSaved: true),
        ];

        await service.saveSavedArticles(articles);
        final loaded = await service.loadSavedArticles();

        expect(loaded.length, 2);
        // Insertion order preserved (position column), not date order.
        expect(loaded[0].title, 'Saved 1');
        expect(loaded[1].title, 'Saved 2');
        expect(loaded[0].isSaved, true);
      });

      test('returns empty list when no saved articles', () async {
        final loaded = await service.loadSavedArticles();
        expect(loaded, isEmpty);
      });
    });

    group('corruption recovery', () {
      test('skips corrupt payload rows instead of losing the list', () async {
        final db = await openMemoryDb();
        final svc = StorageService(
          storage: mockStorage,
          database: FeedDatabase(db: db),
        );
        await svc.saveArticles([_makeArticle(id: 'good-1', title: 'Good')]);

        // Inject a row whose payload fails Article.fromJson (title is a
        // number). Row-level isolation means the good article survives.
        await db.insert(
          'articles',
          {'id': 'bad', 'pub_date': 0, 'payload': '{"id":"bad","title":123}'},
        );

        final loaded = await svc.loadArticles();
        expect(loaded.any((a) => a.id == 'good-1'), isTrue);
      });
    });

    group('saveLastRefreshTime / loadLastRefreshTime', () {
      test('saves and loads last refresh time', () async {
        final time = DateTime(2024, 1, 15, 10, 30);

        await service.saveLastRefreshTime(time);
        final loaded = await service.loadLastRefreshTime();

        expect(loaded, isNotNull);
        expect(loaded!.year, 2024);
        expect(loaded.month, 1);
        expect(loaded.day, 15);
      });

      test('returns null when no time saved', () async {
        final loaded = await service.loadLastRefreshTime();
        expect(loaded, isNull);
      });

      test('deletes time when null is saved', () async {
        await service.saveLastRefreshTime(DateTime.now());
        await service.saveLastRefreshTime(null);

        final loaded = await service.loadLastRefreshTime();
        expect(loaded, isNull);
      });
    });

    group('clearAll', () {
      test('clears all stored data', () async {
        await service.saveArticles([_makeArticle(id: '1', title: 'Test')]);
        await service.saveSavedArticles([
          _makeArticle(id: '2', title: 'Saved'),
        ]);

        await service.clearAll();

        expect(await service.loadArticles(), isEmpty);
        expect(await service.loadSavedArticles(), isEmpty);
      });
    });

    group('clearFeedCache', () {
      test('deletes articles and last refresh but keeps saved articles', () async {
        await service.saveArticles([_makeArticle(id: '1', title: 'Cached')]);
        await service.saveSavedArticles([
          _makeArticle(id: '2', title: 'Saved'),
        ]);
        await service.saveLastRefreshTime(DateTime.now());

        await service.clearFeedCache();

        // Cache is gone…
        expect(await service.loadArticles(), isEmpty);
        expect(await service.loadLastRefreshTime(), isNull);
        // …but user data survives.
        final saved = await service.loadSavedArticles();
        expect(saved.length, 1);
        expect(saved.first.title, 'Saved');
      });

      test('is safe to call on empty storage', () async {
        await service.clearFeedCache();
        expect(await service.loadArticles(), isEmpty);
      });
    });

    group('legacy blob migration', () {
      test('imports pre-sqlite blobs once and marks done', () async {
        final legacyArticles = [
          _makeArticle(id: 'legacy-1', title: 'Legacy'),
        ];
        mockStorage.store['articles'] = jsonEncodeList(legacyArticles);
        mockStorage.store['savedArticles'] = jsonEncodeList([
          _makeArticle(id: 'legacy-saved', title: 'LS', isSaved: true),
        ]);

        final loaded = await service.loadArticles();
        expect(loaded.map((a) => a.id), contains('legacy-1'));

        final saved = await service.loadSavedArticles();
        expect(saved.map((a) => a.id), contains('legacy-saved'));

        // Marker written; blobs removed.
        expect(mockStorage.store['articles_migrated_sqlite_v1'], '1');
        expect(mockStorage.store.containsKey('articles'), isFalse);
        expect(mockStorage.store.containsKey('savedArticles'), isFalse);

        // Second call does not re-import (blob already gone anyway).
        expect(await service.loadArticles().then((a) => a.length), 1);
      });

      test('no migration when marker already present', () async {
        mockStorage.store['articles'] = '[{"id":"x"}]'; // would fail parse
        mockStorage.store['articles_migrated_sqlite_v1'] = '1';

        expect(await service.loadArticles(), isEmpty);
      });
    });
  });
}

String jsonEncodeList(List<Article> articles) =>
    jsonEncode(articles.map((a) => a.toJson()).toList());

Article _makeArticle({
  required String id,
  required String title,
  bool isSaved = false,
  bool isRead = false,
  DateTime? pubDate,
}) {
  return Article(
    id: id,
    title: title,
    description: 'Description for $title',
    fullContent: 'Full content for $title',
    link: 'https://example.com/$id',
    sourceId: 'test',
    sourceName: 'Test Source',
    pubDate: pubDate ?? DateTime.now(),
    isSaved: isSaved,
    isRead: isRead,
  );
}

class MockFlutterSecureStorage implements FlutterSecureStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    store.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    store.clear();
  }

  @override
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.from(store);

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => store.containsKey(key);

  @override
  IOSOptions get iOptions => IOSOptions.defaultOptions;

  @override
  AndroidOptions get aOptions => const AndroidOptions();

  @override
  LinuxOptions get lOptions => const LinuxOptions();

  @override
  WebOptions get webOptions => const WebOptions();

  @override
  MacOsOptions get mOptions => MacOsOptions.defaultOptions;

  @override
  WindowsOptions get wOptions => const WindowsOptions();

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => false;

  @override
  Map<String, List<ValueChanged<String?>>> get getListeners => {};

  @override
  void registerListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterListener({
    required String key,
    required ValueChanged<String?> listener,
  }) {}

  @override
  void unregisterAllListeners() {}

  @override
  void unregisterAllListenersForKey({required String key}) {}

  @override
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged => null;
}
