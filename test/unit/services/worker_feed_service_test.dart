import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:curatedfeeds/services/worker_feed_service.dart';
import 'package:curatedfeeds/models/paginated_response.dart';
import 'package:curatedfeeds/models/filter_params.dart';

void main() {
  group('WorkerFeedService', () {
    late WorkerFeedService service;

    group('fetchArticles', () {
      test('returns PaginatedResponse on successful 200 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'title': 'Test Article',
                  'description': 'Test description',
                  'fullContent': '',
                  'link': 'https://example.com/article1',
                  'sourceId': 'verge',
                  'sourceName': 'The Verge',
                  'pubDate': 1705312800000, // 2024-01-15T10:00:00Z as timestamp
                }
              ],
              'hasMore': false,
              'total': 1,
            }),
            200,
          );
        });

        service = WorkerFeedService(httpClient: mockClient);
        final result = await service.fetchArticles();

        expect(result.items.length, 1);
        expect(result.items.first.title, 'Test Article');
        expect(result.hasMore, false);
        expect(result.total, 1);
      });

      test('throws RateLimitError on HTTP 429 rate limit', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Rate limit exceeded', 429);
        });

        service = WorkerFeedService(httpClient: mockClient);

        expect(
          () => service.fetchArticles(),
          throwsA(isA<RateLimitError>()),
        );
      });

      test('throws on HTTP 500 server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal server error', 500);
        });

        service = WorkerFeedService(httpClient: mockClient);

        expect(
          () => service.fetchArticles(),
          throwsA(isA<Exception>()),
        );
      });

      test('throws on malformed JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json {', 200);
        });

        service = WorkerFeedService(httpClient: mockClient);

        expect(
          () => service.fetchArticles(),
          throwsA(isA<Exception>()),
        );
      });

      test('returns empty items on 200 with no items', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [],
              'hasMore': false,
              'total': 0,
            }),
            200,
          );
        });

        service = WorkerFeedService(httpClient: mockClient);
        final result = await service.fetchArticles();

        expect(result.items.isEmpty, true);
        expect(result.hasMore, false);
        expect(result.total, 0);
      });
    });

    group('fetchArticlesList (backwards compatible)', () {
      test('returns list of articles', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 1,
                  'title': 'Article 1',
                  'description': 'Desc',
                  'fullContent': '',
                  'link': 'https://example.com/1',
                  'sourceId': 'verge',
                  'sourceName': 'The Verge',
                  'pubDate': 1705312800000,
                },
                {
                  'id': 2,
                  'title': 'Article 2',
                  'description': 'Desc 2',
                  'fullContent': '',
                  'link': 'https://example.com/2',
                  'sourceId': 'wired',
                  'sourceName': 'Wired',
                  'pubDate': 1705226400000,
                },
              ],
              'hasMore': false,
              'total': 2,
            }),
            200,
          );
        });

        service = WorkerFeedService(httpClient: mockClient);
        final articles = await service.fetchArticlesList();

        expect(articles.length, 2);
        expect(articles.first.title, 'Article 1');
      });
    });

    group('testConnection', () {
      test('returns true on 200 from health endpoint', () async {
        final mockClient = MockClient((request) async {
          return http.Response('OK', 200);
        });

        service = WorkerFeedService(httpClient: mockClient);
        final result = await service.testConnection();

        expect(result, true);
      });

      test('returns false on non-200 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Service unavailable', 503);
        });

        service = WorkerFeedService(httpClient: mockClient);
        final result = await service.testConnection();

        expect(result, false);
      });

      test('returns false on network error', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Network error');
        });

        service = WorkerFeedService(httpClient: mockClient);
        final result = await service.testConnection();

        expect(result, false);
      });
    });

    group('fetchSources', () {
      test('returns list of sources on 200', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'sources': [
                {'id': 'verge', 'name': 'The Verge', 'category': 'Tech'},
                {'id': 'wired', 'name': 'Wired', 'category': 'Tech'},
              ]
            }),
            200,
          );
        });

        service = WorkerFeedService(httpClient: mockClient);
        final sources = await service.fetchSources();

        expect(sources.length, 2);
        expect(sources.first['id'], 'verge');
      });

      test('throws on HTTP error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not found', 404);
        });

        service = WorkerFeedService(httpClient: mockClient);

        expect(
          () => service.fetchSources(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('fetchFullContent', () {
      test('returns content map on 200', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'text': 'Full article text...',
              'wordCount': 500,
              'url': 'https://example.com/article',
            }),
            200,
          );
        });

        service = WorkerFeedService(httpClient: mockClient);
        final content = await service.fetchFullContent('https://example.com/article');

        expect(content, isNotNull);
        expect(content!['text'], 'Full article text...');
        expect(content['wordCount'], 500);
      });

      test('returns null on HTTP 400 bad request', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode({'error': 'Invalid URL'}), 400);
        });

        service = WorkerFeedService(httpClient: mockClient);
        final content = await service.fetchFullContent('invalid-url');

        // Returns null for 400 per existing behavior
        expect(content, isNull);
      });

      test('returns null on HTTP error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Server error', 500);
        });

        service = WorkerFeedService(httpClient: mockClient);
        final content = await service.fetchFullContent('https://example.com/article');

        expect(content, isNull);
      });
    });
  });
}