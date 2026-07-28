import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:curatedfeeds/models/article.dart';

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

    group('predefinedSources', () {
      test('contains expected sources', () {
        expect(RssFeedService.predefinedSources.isNotEmpty, true);
        expect(RssFeedService.predefinedSources.length, greaterThan(5));
      });

      test('all sources have valid URLs', () {
        for (final source in RssFeedService.predefinedSources) {
          expect(source.url.startsWith('https://'), true);
          expect(source.id.isNotEmpty, true);
          expect(source.name.isNotEmpty, true);
        }
      });
    });
  });
}
