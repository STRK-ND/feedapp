import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:curatedfeeds/services/worker_feed_service.dart';

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
                  'pubDate': 1705312800000,
                },
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

        expect(() => service.fetchArticles(), throwsA(isA<RateLimitError>()));
      });

      test('throws on HTTP 500 server error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal server error', 500);
        });

        service = WorkerFeedService(httpClient: mockClient);

        expect(() => service.fetchArticles(), throwsA(isA<Exception>()));
      });

      test('throws on malformed JSON', () async {
        final mockClient = MockClient((request) async {
          return http.Response('not valid json {', 200);
        });

        service = WorkerFeedService(httpClient: mockClient);

        expect(() => service.fetchArticles(), throwsA(isA<Exception>()));
      });

      test('returns empty items on 200 with no items', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'items': [], 'hasMore': false, 'total': 0}),
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
  });
}
