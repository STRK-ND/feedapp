import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/repositories/feed_repository.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';

void main() {
  late FeedRepository repository;

  setUpAll(() {
    // Reset GetIt once before all tests to avoid "already registered" errors
    GetIt.instance.reset();
  });

  setUp(() async {
    await setupServiceLocator();
    repository = FeedRepository();
  });

  group('FeedRepository', () {
    group('getAllSources', () {
      test('Should return all predefined sources', () async {
        final result = await repository.getAllSources();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
        expect(result.data!.isNotEmpty, true);
      });

      test('Should have expected default sources', () async {
        final result = await repository.getAllSources();

        expect(result.isSuccess, true);
        final sources = result.data!;
        final sourceIds = sources.map((s) => s.id).toList();

        expect(sourceIds, contains('techcrunch'));
        expect(sourceIds, contains('verge'));
        expect(sourceIds, contains('bbc'));
      });
    });

    group('getSourceById', () {
      test('Should return source for valid ID', () async {
        final result = await repository.getSourceById('techcrunch');

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
        expect(result.data!.id, 'techcrunch');
        expect(result.data!.name, 'TechCrunch');
      });

      test('Should return null for invalid ID', () async {
        final result = await repository.getSourceById('nonexistent');

        expect(result.isSuccess, true);
        expect(result.data, isNull);
      });
    });

    group('getSourcesByCategory', () {
      test('Should filter sources by category', () async {
        final result = await repository.getSourcesByCategory('Tech');

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
        expect(result.data!.every((s) => s.category == 'Tech'), true);
      });

      test('Should return all sources for "All" category', () async {
        final result = await repository.getSourcesByCategory('All');

        expect(result.isSuccess, true);
        final allResult = await repository.getAllSources();
        expect(result.data!.length, allResult.data!.length);
      });

      test('Should return empty list for non-existent category', () async {
        final result = await repository.getSourcesByCategory('NonExistent');

        expect(result.isSuccess, true);
        expect(result.data!.isEmpty, true);
      });
    });

    group('getCategories', () {
      test('Should return all categories including "All"', () async {
        final result = await repository.getCategories();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
        expect(result.data!.contains('All'), true);
      });

      test('Should have expected categories', () async {
        final result = await repository.getCategories();

        expect(result.isSuccess, true);
        final categories = result.data!;

        expect(categories, contains('All'));
        expect(categories, contains('Tech'));
        expect(categories, contains('News'));
        expect(categories, contains('Science'));
      });

      test('Should return sorted categories', () async {
        final result = await repository.getCategories();

        expect(result.isSuccess, true);
        final categories = result.data!;

        // Verify it's sorted
        final sorted = List.from(categories)..sort();
        expect(categories, equals(sorted));
      });
    });

    group('getFeedHealth', () {
      test('Should return health map for all sources', () async {
        final result = await repository.getFeedHealth();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);

        final sourcesResult = await repository.getAllSources();
        final sourceCount = sourcesResult.data!.length;

        expect(result.data!.length, sourceCount);
      });

      test('Should mark all sources as healthy initially', () async {
        final result = await repository.getFeedHealth();

        expect(result.isSuccess, true);

        final allHealthy = result.data!.values.every((isHealthy) => isHealthy);
        expect(allHealthy, true);
      });
    });
  });
}
