import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/rss_source.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RssFeedService', () {
    late RssFeedService service;

    setUp(() {
      service = RssFeedService();
    });

    group('getSourceById', () {
      test('returns source for valid id', () {
        final source = service.getSourceById('verge');

        expect(source, isNotNull);
        expect(source!.name, 'The Verge');
      });

      test('returns null for invalid id', () {
        final source = service.getSourceById('nonexistent');

        expect(source, isNull);
      });
    });

    group('getSourceColorFromArticle', () {
      test('returns color from source lookup', () {
        final article = Article(
          id: '1',
          title: 'Test',
          description: '',
          fullContent: '',
          link: 'https://example.com',
          sourceId: 'verge',
          sourceName: 'The Verge',
          pubDate: DateTime.now(),
        );

        final color = service.getSourceColorFromArticle(article);

        expect(color, isNotNull);
      });

      test('falls back to default color if source not found', () {
        final article = Article(
          id: '1',
          title: 'Test',
          description: '',
          fullContent: '',
          link: 'https://example.com',
          sourceId: 'nonexistent',
          sourceName: 'Unknown',
          pubDate: DateTime.now(),
        );

        final color = service.getSourceColorFromArticle(article);

        expect(color, isNotNull);
      });
    });

    group('getSourceNameFromArticle', () {
      test('returns embedded source name', () {
        final article = Article(
          id: '1',
          title: 'Test',
          description: '',
          fullContent: '',
          link: 'https://example.com',
          sourceId: 'verge',
          sourceName: 'The Verge',
          pubDate: DateTime.now(),
        );

        final name = service.getSourceNameFromArticle(article);

        expect(name, 'The Verge');
      });

      test('falls back to source lookup if name is empty', () {
        final article = Article(
          id: '1',
          title: 'Test',
          description: '',
          fullContent: '',
          link: 'https://example.com',
          sourceId: 'verge',
          sourceName: '',
          pubDate: DateTime.now(),
        );

        final name = service.getSourceNameFromArticle(article);

        expect(name, 'The Verge');
      });
    });

    group('sources', () {
      test('contains expected sources', () {
        expect(service.sources.isNotEmpty, true);
        expect(service.sources.length, greaterThan(5));
      });

      test('all sources have valid URLs', () {
        for (final source in service.sources) {
          expect(source.url.startsWith('https://'), true);
          expect(source.id.isNotEmpty, true);
          expect(source.name.isNotEmpty, true);
        }
      });
    });

    group('refreshFromWorker', () {
      setUp(() {
        SharedPreferences.setMockInitialValues({});
      });

      test('parses worker payload, updates registry and caches it', () async {
        const payload = {
          'sources': [
            {
              'id': 'verge',
              'name': 'The Verge',
              'url': 'https://www.theverge.com/rss/index.xml',
              'category': 'Tech',
              'color': '#123456',
              'icon': 'memory',
            },
          ],
        };
        final registry = RssFeedService(
          httpClient: MockClient(
            (request) async => http.Response(jsonEncode(payload), 200),
          ),
        );
        await registry.init();

        expect(await registry.refreshFromWorker(), isTrue);
        expect(registry.sources.single.id, 'verge');
        expect(registry.sources.single.color.toARGB32(), 0xFF123456);
        expect(registry.sources.single.icon.codePoint, Icons.memory.codePoint);

        // Cached for the next launch.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList('source_registry_v1'), isNotNull);
      });

      test('unknown icon falls back to the generic feed icon', () async {
        const payload = {
          'sources': [
            {
              'id': 'x',
              'name': 'X',
              'url': 'https://x.example.com/feed',
              'category': 'Sports',
              'color': 'not-a-color',
              'icon': 'nope',
            },
          ],
        };
        final registry = RssFeedService(
          httpClient: MockClient(
            (request) async => http.Response(jsonEncode(payload), 200),
          ),
        );
        await registry.init();

        expect(await registry.refreshFromWorker(), isTrue);
        expect(registry.sources.single.icon, RssSource.customIcon);
        // Malformed hex falls back to the category color.
        expect(registry.sources.single.color, AppColors.sportsSecondary);
      });

      test('keeps current list on failure', () async {
        final registry = RssFeedService(
          httpClient: MockClient(
            (request) async => http.Response('{"error":"rate_limited"}', 429),
          ),
        );
        await registry.init();
        final before = registry.sources;

        expect(await registry.refreshFromWorker(), isFalse);
        expect(registry.sources, same(before));
      });

      test('init loads the cached list', () async {
        const cached = RssSource(
          id: 'worker-only',
          name: 'Cached',
          url: 'https://example.com/feed',
          category: 'Tech',
          color: Color(0xFF010203),
          icon: Icons.newspaper,
        );
        SharedPreferences.setMockInitialValues({
          'source_registry_v1': [jsonEncode(cached.toJson())],
        });
        final registry = RssFeedService();
        await registry.init();

        expect(registry.sources.single.id, 'worker-only');
        expect(registry.getSourceById('verge'), isNull);
      });
    });
  });
}
