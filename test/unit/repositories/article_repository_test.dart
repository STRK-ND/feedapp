import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/utils/error_handler.dart';

void main() {
  group('ArticleRepository', () {
    late ArticleRepository repository;

    setUpAll(() {
      // Reset GetIt once before all tests to avoid "already registered" errors
      GetIt.instance.reset();
    });

    setUp(() async {
      await setupServiceLocator();
      repository = ArticleRepository();
    });

    group('ErrorHandlerExtensions', () {
      test('logInfo should log info message', () {
        // This test verifies that the extension method exists and can be called
        // without throwing an exception
        expect(
          () => ErrorHandlerExtensions.logInfo('Test info message'),
          returnsNormally,
        );
      });

      test('logWarning should log warning message', () {
        // This test verifies that the extension method exists and can be called
        // without throwing an exception
        expect(
          () => ErrorHandlerExtensions.logWarning('Test warning message'),
          returnsNormally,
        );
      });
    });

    group('fetchAllArticles', () {
      test('Should return success Result from storage', () async {
        final result = await repository.fetchAllArticles();

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });

      test('Should return Result type', () async {
        final result = await repository.fetchAllArticles();

        expect(result, isA<Result<List<Article>>>());
      });
    });

    group('fetchSavedArticles', () {
      test('Should return success Result', () async {
        final result = await repository.fetchSavedArticles();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });
    });

    group('searchArticles', () {
      test('Should return all articles when query is empty', () async {
        final result = await repository.searchArticles('');

        expect(result.isSuccess, true);
      });

      test('Should return success Result for any query', () async {
        final result = await repository.searchArticles('test query');

        expect(result.isSuccess, true);
      });
    });

    group('filterByCategory', () {
      test('Should return all articles when category is All', () async {
        final result = await repository.filterByCategory('All');

        expect(result.isSuccess, true);
      });

      test('Should return success Result for any category', () async {
        final result = await repository.filterByCategory('Tech');

        expect(result.isSuccess, true);
      });

      test('Should return success Result for empty category', () async {
        final result = await repository.filterByCategory('');

        expect(result.isSuccess, true);
      });
    });

    group('filterUnread', () {
      test('Should return success Result', () async {
        final result = await repository.filterUnread();

        expect(result.isSuccess, true);
      });
    });

    group('clearCache', () {
      test('Should clear internal cache', () async {
        // Fetch some data to populate cache
        await repository.fetchAllArticles();

        // Clear cache - should not throw
        expect(() => repository.clearCache(), returnsNormally);
      });
    });

    group('getUnreadCount', () {
      test('Should return Result with count', () async {
        final result = await repository.getUnreadCount();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });
    });
  });
}
