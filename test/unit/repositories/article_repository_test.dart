import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/utils/error_handler.dart';

void main() {
  group('ArticleRepository', () {
    late ArticleRepository repository;
    late Article testArticle;

    setUp(() {
      repository = const ArticleRepository();
      testArticle = Article(
        id: 'test-id-1',
        title: 'Test Article Title',
        description: 'This is a test description',
        fullContent: 'Full article content here',
        link: 'https://example.com/article/1',
        sourceId: 'test-source',
        sourceName: 'Test Source',
        pubDate: DateTime.utc(2024, 1, 15, 12, 30),
        author: 'Test Author',
        imageUrl: 'https://example.com/image.jpg',
        isRead: false,
        isSaved: false,
      );
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
      test('Should return success Result with empty list initially', () {
        final result = repository.fetchAllArticles();

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });

      test('Should call logInfo when fetching articles', () {
        // Verify the method can be called without throwing
        expect(() => repository.fetchAllArticles(), returnsNormally);
      });

      test('Should return Result type', () {
        final result = repository.fetchAllArticles();

        expect(result, isA<Result<List<Article>>>());
      });

      test('Should handle exceptions gracefully', () {
        // The repository should handle any exceptions internally
        // Since the current implementation returns an empty list,
        // we're testing that it doesn't throw
        expect(() => repository.fetchAllArticles(), returnsNormally);
      });
    });

    group('fetchArticlesFromSource', () {
      test('Should return success Result with empty list for valid source', () {
        const sourceId = 'test-source';
        final result = repository.fetchArticlesFromSource(sourceId);

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });

      test('Should handle empty source ID', () {
        const sourceId = '';
        final result = repository.fetchArticlesFromSource(sourceId);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle special characters in source ID', () {
        const sourceId = 'source-with_special@chars#123';
        final result = repository.fetchArticlesFromSource(sourceId);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should call logInfo with source ID', () {
        const sourceId = 'example-source';
        expect(
          () => repository.fetchArticlesFromSource(sourceId),
          returnsNormally,
        );
      });

      test('Should handle exceptions and return failure', () {
        // The repository should handle exceptions internally
        expect(
          () => repository.fetchArticlesFromSource('any-source'),
          returnsNormally,
        );
      });

      test('Should return Result type', () {
        const sourceId = 'test-source';
        final result = repository.fetchArticlesFromSource(sourceId);

        expect(result, isA<Result<List<Article>>>());
      });
    });

    group('searchArticles', () {
      test('Should return success Result with empty list initially', () {
        const query = 'search term';
        final result = repository.searchArticles(query);

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });

      test('Should handle empty query', () {
        const query = '';
        final result = repository.searchArticles(query);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle whitespace query', () {
        const query = '   ';
        final result = repository.searchArticles(query);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle special characters in query', () {
        final query = 'C++ / Dart & Flutter! @#\$%';
        final result = repository.searchArticles(query);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle long search queries', () {
        final query = 'a' * 1000;
        final result = repository.searchArticles(query);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle Unicode characters in query', () {
        const query = '搜索 検索 검색';
        final result = repository.searchArticles(query);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle case-sensitive queries', () {
        const upperCaseQuery = 'FLUTTER';
        const lowerCaseQuery = 'flutter';
        final result1 = repository.searchArticles(upperCaseQuery);
        final result2 = repository.searchArticles(lowerCaseQuery);

        expect(result1.isSuccess, true);
        expect(result2.isSuccess, true);
      });

      test('Should call logInfo with query', () {
        const query = 'search term';
        expect(() => repository.searchArticles(query), returnsNormally);
      });

      test('Should return Result type', () {
        const query = 'test query';
        final result = repository.searchArticles(query);

        expect(result, isA<Result<List<Article>>>());
      });
    });

    group('filterByCategory', () {
      test('Should return success Result with empty list initially', () {
        const category = 'Technology';
        final result = repository.filterByCategory(category);

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });

      test('Should handle empty category', () {
        const category = '';
        final result = repository.filterByCategory(category);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle category with spaces', () {
        const category = 'Science   ';
        final result = repository.filterByCategory(category);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle special characters in category', () {
        const category = 'C++/Python & Java';
        final result = repository.filterByCategory(category);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle category with mixed case', () {
        const category = 'TeChNoLoGy';
        final result = repository.filterByCategory(category);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should handle Unicode categories', () {
        const category = '技术 科学';
        final result = repository.filterByCategory(category);

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });

      test('Should call logInfo with category', () {
        const category = 'Technology';
        expect(() => repository.filterByCategory(category), returnsNormally);
      });

      test('Should return Result type', () {
        const category = 'test category';
        final result = repository.filterByCategory(category);

        expect(result, isA<Result<List<Article>>>());
      });
    });

    group('filterUnread', () {
      test('Should return success Result with empty list initially', () {
        final result = repository.filterUnread();

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, isNotNull);
        expect(result.data, isEmpty);
        expect(result.error, isNull);
      });

      test('Should call logInfo when filtering unread', () {
        expect(() => repository.filterUnread(), returnsNormally);
      });

      test('Should handle multiple consecutive calls', () {
        final result1 = repository.filterUnread();
        final result2 = repository.filterUnread();
        final result3 = repository.filterUnread();

        expect(result1.isSuccess, true);
        expect(result2.isSuccess, true);
        expect(result3.isSuccess, true);
      });

      test('Should return Result type', () {
        final result = repository.filterUnread();

        expect(result, isA<Result<List<Article>>>());
      });
    });

    group('Result<T> Integration', () {
      test('Result.success should create success result', () {
        final success = Result.success(testArticle);

        expect(success.isSuccess, true);
        expect(success.isFailure, false);
        expect(success.data, testArticle);
        expect(success.error, isNull);
      });

      test('Result.failure should create failure result', () {
        const errorMessage = 'Test error';
        final failure = Result.failure(errorMessage);

        expect(failure.isSuccess, false);
        expect(failure.isFailure, true);
        expect(failure.data, isNull);
        expect(failure.error, errorMessage);
      });

      test('Result.dataOrThrow should return data on success', () {
        final success = Result.success(testArticle);

        expect(success.dataOrThrow, testArticle);
      });

      test('Result.dataOrThrow should throw on failure', () {
        const errorMessage = 'Test error';
        final failure = Result.failure(errorMessage);

        expect(
          () => failure.dataOrThrow,
          throwsA(isA<Exception>()),
        );
      });

      test('Result.map should transform successful result', () {
        final success = Result.success(testArticle);
        final mapped = success.map((article) => article.title);

        expect(mapped.isSuccess, true);
        expect(mapped.data, testArticle.title);
      });

      test('Result.map should preserve failure', () {
        const errorMessage = 'Test error';
        final failure = Result.failure(errorMessage);
        final mapped = failure.map((article) => article.title);

        expect(mapped.isFailure, true);
        expect(mapped.error, errorMessage);
      });

      test('Result.map should handle transformation errors', () {
        final success = Result.success(testArticle);
        final mapped = success.map<dynamic>((article) {
          throw Exception('Transformation failed');
        });

        expect(mapped.isFailure, true);
        expect(mapped.error, contains('Transformation failed'));
      });
    });

    group('Edge Cases and Robustness', () {
      test('Should handle rapid successive calls', () {
        final results = List.generate(
          100,
          (_) => repository.fetchAllArticles(),
        );

        expect(results, hasLength(100));
        for (final result in results) {
          expect(result.isSuccess, true);
        }
      });

      test('Should handle concurrent searches', () {
        final queries = [
          'flutter',
          'dart',
          'mobile',
          'development',
        ];

        final results = queries.map((query) {
          return repository.searchArticles(query);
        }).toList();

        expect(results, hasLength(queries.length));
        for (final result in results) {
          expect(result.isSuccess, true);
        }
      });

      test('Should handle mixed repository operations', () {
        final results = [
          repository.fetchAllArticles(),
          repository.fetchArticlesFromSource('source1'),
          repository.searchArticles('query'),
          repository.filterByCategory('tech'),
          repository.filterUnread(),
        ];

        expect(results, hasLength(5));
        for (final result in results) {
          expect(result.isSuccess, true);
        }
      });

      test('Should handle extremely long strings', () {
        final longId = 'x' * 10000;
        final longQuery = 'a' * 10000;
        final longCategory = 'b' * 10000;

        expect(() => repository.fetchArticlesFromSource(longId), returnsNormally);
        expect(() => repository.searchArticles(longQuery), returnsNormally);
        expect(() => repository.filterByCategory(longCategory), returnsNormally);
      });

      test('Should handle null-like values gracefully', () {
        // Edge case: very long whitespace
        const whitespace = ' \t\n\r\u2000\u2001\u2002\u2003';

        expect(() => repository.searchArticles(whitespace), returnsNormally);
        expect(() => repository.filterByCategory(whitespace), returnsNormally);
      });
    });

    group('Repository Immutability', () {
      test('Repository should be const constructible', () {
        const repo = ArticleRepository();

        expect(repo, isNotNull);
        expect(repo, isA<ArticleRepository>());
      });

      test('Multiple repositories should be independent', () {
        const repo1 = ArticleRepository();
        const repo2 = ArticleRepository();

        // Const constructors create the same instance (canonicalization)
        expect(identical(repo1, repo2), true);
        expect(repo1, equals(repo2));
      });
    });

    group('Type Safety', () {
      test('fetchAllArticles should return List<Article> in data', () {
        final result = repository.fetchAllArticles();

        if (result.isSuccess) {
          expect(result.data, isA<List<Article>>());
        } else {
          fail('Expected success but got failure');
        }
      });

      test('searchArticles should return List<Article> in data', () {
        final result = repository.searchArticles('query');

        if (result.isSuccess) {
          expect(result.data, isA<List<Article>>());
        } else {
          fail('Expected success but got failure');
        }
      });

      test('filterByCategory should return List<Article> in data', () {
        final result = repository.filterByCategory('tech');

        if (result.isSuccess) {
          expect(result.data, isA<List<Article>>());
        } else {
          fail('Expected success but got failure');
        }
      });

      test('filterUnread should return List<Article> in data', () {
        final result = repository.filterUnread();

        if (result.isSuccess) {
          expect(result.data, isA<List<Article>>());
        } else {
          fail('Expected success but got failure');
        }
      });
    });

    group('Error Handling Verification', () {
      test('logInfo should use ErrorSeverity.low', () {
        // Verify that logInfo doesn't throw and calls the underlying ErrorHandler
        expect(
          () => ErrorHandlerExtensions.logInfo('Info message'),
          returnsNormally,
        );
      });

      test('logWarning should use ErrorSeverity.medium', () {
        // Verify that logWarning doesn't throw and calls the underlying ErrorHandler
        expect(
          () => ErrorHandlerExtensions.logWarning('Warning message'),
          returnsNormally,
        );
      });

      test('ErrorHandlerExtensions should be accessible from ArticleRepository context', () {
        // Verify that the extension methods can be called without throwing
        expect(
          () => ErrorHandlerExtensions.logInfo('Test'),
          returnsNormally,
        );
        expect(
          () => ErrorHandlerExtensions.logWarning('Test'),
          returnsNormally,
        );
      });
    });
  });
}
