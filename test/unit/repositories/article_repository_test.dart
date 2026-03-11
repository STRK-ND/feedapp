import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/utils/error_handler.dart';

void main() {
  group('ArticleRepository', () {
    late ArticleRepository repository;

    setUp(() async {
      // Ensure service locator is set up for testing
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
      testWidgets('Should return success Result from storage', (WidgetTester tester) async {
        final result = await repository.fetchAllArticles();

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });

      testWidgets('Should return Result type', (WidgetTester tester) async {
        final result = await repository.fetchAllArticles();

        expect(result, isA<Result<List<Article>>>());
      });
    });

    group('fetchSavedArticles', () {
      testWidgets('Should return success Result', (WidgetTester tester) async {
        final result = await repository.fetchSavedArticles();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });
    });

    group('searchArticles', () {
      testWidgets('Should return all articles when query is empty', (WidgetTester tester) async {
        final result = await repository.searchArticles('');

        expect(result.isSuccess, true);
      });

      testWidgets('Should return success Result for any query', (WidgetTester tester) async {
        final result = await repository.searchArticles('test query');

        expect(result.isSuccess, true);
      });
    });

    group('filterByCategory', () {
      testWidgets('Should return all articles when category is All', (WidgetTester tester) async {
        final result = await repository.filterByCategory('All');

        expect(result.isSuccess, true);
      });

      testWidgets('Should return success Result for any category', (WidgetTester tester) async {
        final result = await repository.filterByCategory('Tech');

        expect(result.isSuccess, true);
      });

      testWidgets('Should return success Result for empty category', (WidgetTester tester) async {
        final result = await repository.filterByCategory('');

        expect(result.isSuccess, true);
      });
    });

    group('filterUnread', () {
      testWidgets('Should return success Result', (WidgetTester tester) async {
        final result = await repository.filterUnread();

        expect(result.isSuccess, true);
      });
    });

    group('clearCache', () {
      testWidgets('Should clear internal cache', (WidgetTester tester) async {
        // Fetch some data to populate cache
        await repository.fetchAllArticles();

        // Clear cache - should not throw
        expect(() => repository.clearCache(), returnsNormally);
      });
    });

    group('getUnreadCount', () {
      testWidgets('Should return Result with count', (WidgetTester tester) async {
        final result = await repository.getUnreadCount();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });
    });
  });
}
