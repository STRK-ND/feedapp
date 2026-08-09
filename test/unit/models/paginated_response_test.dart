import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/models/paginated_response.dart';

void main() {
  group('PaginatedResponse Model', () {
    late Article testArticle1;
    late Article testArticle2;

    setUp(() {
      testArticle1 = Article(
        id: 'test-id-1',
        title: 'Test Article 1',
        description: 'Description 1',
        fullContent: 'Content 1',
        link: 'https://example.com/article/1',
        sourceId: 'source-1',
        sourceName: 'Source 1',
        pubDate: DateTime.fromMillisecondsSinceEpoch(1705314600000),
        author: 'Author 1',
        imageUrl: 'https://example.com/image1.jpg',
      );

      testArticle2 = Article(
        id: 'test-id-2',
        title: 'Test Article 2',
        description: 'Description 2',
        fullContent: 'Content 2',
        link: 'https://example.com/article/2',
        sourceId: 'source-2',
        sourceName: 'Source 2',
        pubDate: DateTime.fromMillisecondsSinceEpoch(1705314700000),
        author: 'Author 2',
        imageUrl: 'https://example.com/image2.jpg',
      );
    });

    test('Should create PaginatedResponse with correct values', () {
      final response = PaginatedResponse(
        items: [testArticle1, testArticle2],
        total: 100,
        page: 1,
        pageSize: 50,
        hasMore: true,
      );

      expect(response.items.length, 2);
      expect(response.items[0].id, 'test-id-1');
      expect(response.items[1].id, 'test-id-2');
      expect(response.total, 100);
      expect(response.page, 1);
      expect(response.pageSize, 50);
      expect(response.hasMore, true);
    });

    group('nextPage getter', () {
      test('Should return next page number when hasMore is true', () {
        final response = PaginatedResponse(
          items: [testArticle1],
          total: 100,
          page: 1,
          pageSize: 50,
          hasMore: true,
        );

        expect(response.nextPage, 2);
      });

      test('Should return null when hasMore is false', () {
        final response = PaginatedResponse(
          items: [testArticle1],
          total: 100,
          page: 2,
          pageSize: 50,
          hasMore: false,
        );

        expect(response.nextPage, isNull);
      });
    });

    group('totalPages getter', () {
      test(
        'Should calculate total pages correctly when total divides evenly',
        () {
          final response = PaginatedResponse(
            items: [testArticle1],
            total: 100,
            page: 1,
            pageSize: 50,
            hasMore: true,
          );

          expect(response.totalPages, 2);
        },
      );

      test(
        'Should calculate total pages correctly when there is remainder',
        () {
          final response = PaginatedResponse(
            items: [testArticle1],
            total: 105,
            page: 1,
            pageSize: 50,
            hasMore: true,
          );

          expect(response.totalPages, 3);
        },
      );

      test('Should return 0 when total is 0', () {
        final response = PaginatedResponse(
          items: [],
          total: 0,
          page: 1,
          pageSize: 50,
          hasMore: false,
        );

        expect(response.totalPages, 0);
      });

      test('Should return 1 when total is less than pageSize', () {
        final response = PaginatedResponse(
          items: [testArticle1],
          total: 25,
          page: 1,
          pageSize: 50,
          hasMore: false,
        );

        expect(response.totalPages, 1);
      });
    });

    group('fromJson', () {
      test('Should create PaginatedResponse from JSON correctly', () {
        final json = {
          'items': [testArticle1.toJson(), testArticle2.toJson()],
          'total': 100,
          'page': 1,
          'pageSize': 50,
          'hasMore': true,
        };

        final response = PaginatedResponse.fromJson(json);

        expect(response.items.length, 2);
        expect(response.items[0].id, 'test-id-1');
        expect(response.items[0].title, 'Test Article 1');
        expect(response.items[1].id, 'test-id-2');
        expect(response.items[1].title, 'Test Article 2');
        expect(response.total, 100);
        expect(response.page, 1);
        expect(response.pageSize, 50);
        expect(response.hasMore, true);
      });

      test('Should use default values for missing fields', () {
        final json = {'items': []};

        final response = PaginatedResponse.fromJson(json);

        expect(response.items, isEmpty);
        expect(response.total, 0);
        expect(response.page, 1);
        expect(response.pageSize, 50);
        expect(response.hasMore, false);
      });

      test('Should handle null values gracefully', () {
        final json = {
          'items': null,
          'total': null,
          'page': null,
          'pageSize': null,
          'hasMore': null,
        };

        final response = PaginatedResponse.fromJson(json);

        expect(response.items, isEmpty);
        expect(response.total, 0);
        expect(response.page, 1);
        expect(response.pageSize, 50);
        expect(response.hasMore, false);
      });
    });
  });
}
