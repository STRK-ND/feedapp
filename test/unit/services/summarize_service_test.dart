// AI summaries client contract: body selection/clamping, the free-trial
// counter, cache-before-network, and the worker response mapping.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/services/summarize_service.dart';

Article makeArticle({String? fullContent, String? description}) {
  return Article(
    id: 'a1',
    title: 'Title',
    description: description ?? 'Short teaser.',
    fullContent: fullContent ?? '',
    link: 'https://example.com/1',
    sourceId: 'verge',
    sourceName: 'The Verge',
    pubDate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('summarizableBody', () {
    test('prefers the extracted body over the description', () {
      final body = SummarizeService.summarizableBody(
        makeArticle(fullContent: 'F' * 300, description: 'D' * 500),
      );
      expect(body, 'F' * 300);
    });

    test('falls back to the description when there is no fullContent', () {
      expect(
        SummarizeService.summarizableBody(makeArticle(description: 'D' * 300)),
        'D' * 300,
      );
    });

    test('null when the body is too short for the worker', () {
      expect(
        SummarizeService.summarizableBody(makeArticle(description: 'hi')),
        isNull,
      );
    });

    test('clamps to the worker limit', () {
      final body = SummarizeService.summarizableBody(
        makeArticle(fullContent: 'x' * 9000),
      );
      expect(body!.length, kSummaryMaxTextChars);
    });
  });

  group('free trial counter', () {
    test('fresh month starts at the full allowance and decrements', () async {
      SharedPreferences.setMockInitialValues({});
      final service = SummarizeService();
      expect(await service.remainingFreeTrial(), kFreeTrialMonthlySummaries);

      await service.recordFreeUse();
      await service.recordFreeUse();
      expect(
        await service.remainingFreeTrial(),
        kFreeTrialMonthlySummaries - 2,
      );
    });

    test('a stale month key resets the allowance', () async {
      final lastMonth = DateTime.now().toUtc();
      final ym = SummarizeService.currentYm(
        DateTime(
          lastMonth.year,
          lastMonth.month == 1 ? 12 : lastMonth.month - 1,
        ),
      );
      SharedPreferences.setMockInitialValues({
        'summary_free_ym': ym,
        'summary_free_used': kFreeTrialMonthlySummaries,
      });
      final service = SummarizeService();
      expect(await service.remainingFreeTrial(), kFreeTrialMonthlySummaries);
    });

    test('exhausted allowance reads zero', () async {
      SharedPreferences.setMockInitialValues({
        'summary_free_ym': SummarizeService.currentYm(DateTime.now().toUtc()),
        'summary_free_used': kFreeTrialMonthlySummaries,
      });
      final service = SummarizeService();
      expect(await service.remainingFreeTrial(), 0);
    });
  });

  group('summarize request mapping', () {
    late SummarizeService service;
    late List<http.Request> requests;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      requests = [];
    });

    SummarizeService makeService({
      required http.Client client,
      String? persisted,
    }) {
      return SummarizeService(
        httpClient: client,
        idTokenProvider: () async => 'id-token',
      );
    }

    test('memory cache hit never touches the network', () async {
      service = makeService(
        client: MockClient((r) async {
          requests.add(r);
          return http.Response('{"summary":"s"}', 200);
        }),
      );
      service.primeCache('a1', 'Cached bullets');
      final result = await service.summarize(
        makeArticle(fullContent: 'B' * 300),
      );
      expect(result.status, SummaryStatus.success);
      expect(result.summary, 'Cached bullets');
      expect(requests, isEmpty);
    });

    test(
      'persistent cache hit primes the memory cache without network',
      () async {
        service = makeService(
          client: MockClient((r) async {
            requests.add(r);
            return http.Response('{"summary":"s"}', 200);
          }),
        );
        const persisted = 'Persisted bullets';
        final result = await service.summarize(
          makeArticle(fullContent: 'B' * 300),
          persistentLookup: (_) async => persisted,
        );
        expect(result.summary, 'Persisted bullets');
        expect(requests, isEmpty);
        // Second call is served from memory.
        final again = await service.summarize(
          makeArticle(fullContent: 'B' * 300),
          persistentLookup: (_) async => persisted,
        );
        expect(again.summary, 'Persisted bullets');
      },
    );

    test('200 persists the summary and sends auth + clamped body', () async {
      String? saved;
      service = SummarizeService(
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response('{"summary":"- a\\n- b\\n- c"}', 200);
        }),
        idTokenProvider: () async => 'id-token',
      );
      final result = await service.summarize(
        makeArticle(fullContent: 'B' * 300),
        persist: (id, text) async => saved = text,
      );

      expect(result.status, SummaryStatus.success);
      expect(saved, '- a\n- b\n- c');
      expect(requests.single.url.path, endsWith('/summarize'));
      expect(requests.single.headers['authorization'], 'Bearer id-token');
      final sent = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(sent['articleId'], 'a1');
      expect(sent['text'], 'B' * 300);
    });

    test('429 budget_exhausted and rate_limited map distinctly', () async {
      service = SummarizeService(
        httpClient: MockClient(
          (r) async => http.Response('{"error":"budget_exhausted"}', 429),
        ),
        idTokenProvider: () async => 'id-token',
      );
      expect(
        (await service.summarize(makeArticle(fullContent: 'B' * 300))).status,
        SummaryStatus.budgetExhausted,
      );

      service = SummarizeService(
        httpClient: MockClient(
          (r) async => http.Response('{"error":"rate_limited"}', 429),
        ),
        idTokenProvider: () async => 'id-token',
      );
      expect(
        (await service.summarize(makeArticle(fullContent: 'B' * 300))).status,
        SummaryStatus.rateLimited,
      );
    });

    test(
      '401 maps to authFailed; 5xx and transport errors to failed',
      () async {
        service = SummarizeService(
          httpClient: MockClient((r) async => http.Response('{}', 401)),
          idTokenProvider: () async => 'id-token',
        );
        expect(
          (await service.summarize(makeArticle(fullContent: 'B' * 300))).status,
          SummaryStatus.authFailed,
        );

        service = SummarizeService(
          httpClient: MockClient((r) async => http.Response('{}', 502)),
          idTokenProvider: () async => 'id-token',
        );
        expect(
          (await service.summarize(makeArticle(fullContent: 'B' * 300))).status,
          SummaryStatus.failed,
        );

        service = SummarizeService(
          httpClient: MockClient((r) async => throw Exception('offline')),
          idTokenProvider: () async => 'id-token',
        );
        expect(
          (await service.summarize(makeArticle(fullContent: 'B' * 300))).status,
          SummaryStatus.failed,
        );
      },
    );

    test(
      'signed-out (no token) and too-short bodies fail without network',
      () async {
        service = SummarizeService(
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response('{}', 200);
          }),
          idTokenProvider: () async => null,
        );
        expect(
          (await service.summarize(makeArticle(fullContent: 'B' * 300))).status,
          SummaryStatus.authFailed,
        );

        service = SummarizeService(
          httpClient: MockClient((r) async {
            requests.add(r);
            return http.Response('{}', 200);
          }),
          idTokenProvider: () async => 'id-token',
        );
        expect(
          (await service.summarize(makeArticle(description: 'tiny'))).status,
          SummaryStatus.failed,
        );
        expect(requests, isEmpty);
      },
    );
  });
}
