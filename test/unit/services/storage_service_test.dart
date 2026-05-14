import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/services/storage_service.dart';
import 'package:curatedfeeds/services/key_value_storage.dart';
import 'package:curatedfeeds/models/article.dart';

void main() {
  group('StorageService', () {
    late StorageService service;
    late MockKeyValueStorage mockStorage;

    setUp(() {
      mockStorage = MockKeyValueStorage();
      service = StorageService(storage: mockStorage);
    });

    group('saveArticles / loadArticles', () {
      test('saves and loads articles roundtrip', () async {
        final articles = [
          _makeArticle(id: '1', title: 'Article 1'),
          _makeArticle(id: '2', title: 'Article 2'),
        ];

        await service.saveArticles(articles);
        final loaded = await service.loadArticles();

        expect(loaded.length, 2);
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

      test('enforces article limit when saving', () async {
        final manyArticles = List.generate(
          1500,
          (i) => _makeArticle(id: '$i', title: 'Article $i'),
        );

        await service.saveArticles(manyArticles);
        final loaded = await service.loadArticles();

        // Should be limited to maxCachedArticles (1000)
        expect(loaded.length, lessThanOrEqualTo(1000));
      });
    });

    group('saveSavedArticles / loadSavedArticles', () {
      test('saves and loads saved articles roundtrip', () async {
        final articles = [
          _makeArticle(id: '1', title: 'Saved 1', isSaved: true),
          _makeArticle(id: '2', title: 'Saved 2', isSaved: true),
        ];

        await service.saveSavedArticles(articles);
        final loaded = await service.loadSavedArticles();

        expect(loaded.length, 2);
        expect(loaded[0].isSaved, true);
        expect(loaded[1].isSaved, true);
      });

      test('returns empty list when no saved articles', () async {
        final loaded = await service.loadSavedArticles();
        expect(loaded, isEmpty);
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

    group('saveViewMode / loadViewMode', () {
      test('saves and loads view mode', () async {
        await service.saveViewMode('card');
        final loaded = await service.loadViewMode();

        expect(loaded, 'card');
      });

      test('returns null when no view mode saved', () async {
        final loaded = await service.loadViewMode();
        expect(loaded, isNull);
      });

      test('overwrites previous view mode', () async {
        await service.saveViewMode('card');
        await service.saveViewMode('list');

        final loaded = await service.loadViewMode();
        expect(loaded, 'list');
      });
    });

    group('clearAll', () {
      test('clears all stored data', () async {
        await service.saveArticles([_makeArticle(id: '1', title: 'Test')]);
        await service.saveSavedArticles([_makeArticle(id: '2', title: 'Saved')]);
        await service.saveViewMode('card');

        await service.clearAll();

        expect(await service.loadArticles(), isEmpty);
        expect(await service.loadSavedArticles(), isEmpty);
        expect(await service.loadViewMode(), isNull);
      });
    });

    group('storage corruption recovery', () {
      test('returns empty list on corrupted JSON', () async {
        mockStorage.store['articles'] = 'not valid json {{{';

        final loaded = await service.loadArticles();
        expect(loaded, isEmpty);
      });

      test('returns empty saved articles on corrupted JSON', () async {
        mockStorage.store['savedArticles'] = 'corrupted';

        final loaded = await service.loadSavedArticles();
        expect(loaded, isEmpty);
      });

      test('returns null for last refresh on invalid date string', () async {
        mockStorage.store['lastRefresh'] = 'not-a-date';

        final loaded = await service.loadLastRefreshTime();
        expect(loaded, isNull);
      });
    });
  });
}

Article _makeArticle({
  required String id,
  required String title,
  bool isSaved = false,
  bool isRead = false,
}) {
  return Article(
    id: id,
    title: title,
    description: 'Description for $title',
    fullContent: 'Full content for $title',
    link: 'https://example.com/$id',
    sourceId: 'test',
    sourceName: 'Test Source',
    pubDate: DateTime.now(),
    isSaved: isSaved,
    isRead: isRead,
  );
}

class MockKeyValueStorage implements KeyValueStorage {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      store.remove(key);
    } else {
      store[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    store.clear();
  }
}