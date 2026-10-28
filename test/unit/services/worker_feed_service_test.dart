import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:curatedfeeds/services/worker_feed_service.dart';
import 'package:curatedfeeds/services/worker_errors.dart';
import 'package:curatedfeeds/utils/error_handler.dart';

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

      test('a busy 503 is retried and then serves the feed', () async {
        var calls = 0;
        final mockClient = MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              jsonEncode({'error': 'busy', 'message': 'Feed is refreshing'}),
              503,
              headers: {'content-type': 'application/json'},
            );
          }
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
            headers: {'content-type': 'application/json'},
          );
        });

        service = WorkerFeedService(httpClient: mockClient);
        final result = await service.fetchArticles();

        expect(calls, 2, reason: 'the busy answer must not fail the fetch');
        expect(result.items.length, 1);
        expect(result.items.first.title, 'Test Article');
      });

      test(
        'a persistent busy 503 throws WorkerBusyException with the worker reason',
        () async {
          final mockClient = MockClient((request) async {
            return http.Response(
              jsonEncode({'error': 'busy', 'message': 'Feed is refreshing'}),
              503,
              headers: {'content-type': 'application/json'},
            );
          });

          service = WorkerFeedService(httpClient: mockClient);

          await expectLater(
            service.fetchArticles(),
            throwsA(
              isA<WorkerBusyException>().having(
                (error) => error.message,
                'message',
                'Feed is refreshing',
              ),
            ),
          );
        },
      );

      test(
        'a 503 that is not busy is a server fault, not a busy feed',
        () async {
          final mockClient = MockClient((request) async {
            return http.Response('upstream exploded', 503);
          });

          service = WorkerFeedService(httpClient: mockClient);

          try {
            await service.fetchArticles();
            fail('expected fetchArticles to throw');
          } on WorkerBusyException {
            fail('a plain 503 must not be read as a busy feed');
          } catch (_) {
            // A real server fault: any other exception is correct here.
          }
        },
      );

      test('getUserMessage names the busy feed instead of a server error', () {
        expect(
          ErrorHandler.getUserMessage(
            WorkerBusyException(message: 'Feed is refreshing'),
          ),
          'Feed is refreshing. Try again in a moment.',
        );
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

      // Regression: the endpoint is built from the worker BASE — it must
      // resolve to /articles, not stay on the base path. A plain
      // Uri.parse(base).replace(qp) kept "/" and the worker 404'd in
      // production (the default base has no per-endpoint override in CI).
      test('requests the /articles path, not the bare worker base', () async {
        String requestedPath = '';
        final mockClient = MockClient((request) async {
          requestedPath = request.url.path;
          return http.Response(
            jsonEncode({'items': [], 'hasMore': false, 'total': 0}),
            200,
          );
        });

        service = WorkerFeedService(httpClient: mockClient);
        await service.fetchArticles();

        expect(requestedPath, '/articles');
      });
    });
  });
}
