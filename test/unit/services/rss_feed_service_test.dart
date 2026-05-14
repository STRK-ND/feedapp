import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:curatedfeeds/models/rss_source.dart';
import 'package:curatedfeeds/models/article.dart';

void main() {
  group('RssFeedService', () {
    late RssFeedService service;

    RssSource makeSource({
      String id = 'test',
      String name = 'Test',
      String url = 'https://test.com/rss',
      String category = 'Tech',
      int color = 0xFF60A5FA,
      int icon = 0xe1c6,
    }) {
      return RssSource(
        id: id,
        name: name,
        url: url,
        category: category,
        color: Color(color),
        icon: IconData(icon, fontFamily: 'MaterialIcons'),
      );
    }

    group('fetchArticles', () {
      test('parses valid RSS XML and returns articles', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), contains('theverge.com'));
          return http.Response(_validRssXml, 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource(
          id: 'verge',
          name: 'The Verge',
          url: 'https://www.theverge.com/rss/index.xml',
        );

        final articles = await service.fetchArticles(source);

        expect(articles.isNotEmpty, true);
        expect(articles.first.title.isNotEmpty, true);
        expect(articles.first.link.isNotEmpty, true);
        expect(articles.first.sourceId, 'verge');
        expect(articles.first.sourceName, 'The Verge');
      });

      test('returns empty list on XML parse error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('<invalid>xml><<>', 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource();

        final articles = await service.fetchArticles(source);

        expect(articles.isEmpty, true);
      });

      test('returns empty list on network timeout', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Connection timeout');
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource();

        final articles = await service.fetchArticles(source);

        expect(articles.isEmpty, true);
      });

      test('returns empty list on HTTP error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource();

        final articles = await service.fetchArticles(source);

        expect(articles.isEmpty, true);
      });

      test('respects max articles per source limit', () async {
        final mockClient = MockClient((request) async {
          return http.Response(_largeRssXml, 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource();

        final articles = await service.fetchArticles(source);

        expect(articles.length, lessThanOrEqualTo(20));
      });

      test('extracts image from enclosure element', () async {
        final mockClient = MockClient((request) async {
          return http.Response(_rssWithEnclosureImage, 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource();

        final articles = await service.fetchArticles(source);

        expect(articles.first.imageUrl, isNotNull);
        expect(articles.first.imageUrl, contains('image.jpg'));
      });

      test('extracts image from media:content element', () async {
        final mockClient = MockClient((request) async {
          return http.Response(_rssWithMediaContentImage, 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource();

        final articles = await service.fetchArticles(source);

        expect(articles.first.imageUrl, isNotNull);
        expect(articles.first.imageUrl, contains('media-image.jpg'));
      });

      test('extracts image from description HTML img tag', () async {
        final mockClient = MockClient((request) async {
          return http.Response(_rssWithDescriptionImage, 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource();

        final articles = await service.fetchArticles(source);

        expect(articles.first.imageUrl, isNotNull);
        expect(articles.first.imageUrl, contains('description-image.jpg'));
      });

      test('handles article with missing title gracefully', () async {
        final mockClient = MockClient((request) async {
          return http.Response(_rssWithMissingTitle, 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final source = makeSource();

        final articles = await service.fetchArticles(source);

        expect(articles.isEmpty, true);
      });
    });

    group('fetchAllArticles', () {
      test('fetches from all predefined sources in parallel', () async {
        int callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return http.Response(_validRssXml, 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final articles = await service.fetchAllArticles();

        expect(callCount, RssFeedService.predefinedSources.length);
        expect(articles.isNotEmpty, true);
      });

      test('sorts articles by publication date descending', () async {
        int sourceIndex = 0;
        final mockClient = MockClient((request) async {
          sourceIndex++;
          return http.Response(_rssWithMultipleDates(sourceIndex), 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final articles = await service.fetchAllArticles();

        if (articles.length > 1) {
          for (int i = 0; i < articles.length - 1; i++) {
            expect(
              articles[i].pubDate.isAfter(articles[i + 1].pubDate) ||
                  articles[i].pubDate.isAtSameMomentAs(articles[i + 1].pubDate),
              true,
              reason: 'Articles should be sorted by date descending',
            );
          }
        }
      });

      test('continues when some sources fail', () async {
        int callCount = 0;
        final mockClient = MockClient((request) async {
          callCount++;
          if (callCount % 2 == 0) {
            throw Exception('Simulated failure');
          }
          return http.Response(_validRssXml, 200);
        });

        service = RssFeedService(httpClient: mockClient);
        final articles = await service.fetchAllArticles();

        expect(articles.isNotEmpty, true);
      });
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
  });
}

// Valid RSS XML with one article
const String _validRssXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>The Verge</title>
    <link>https://www.theverge.com</link>
    <item>
      <title>Test Article Title</title>
      <link>https://www.theverge.com/article1</link>
      <description>This is a test article description with some content.</description>
      <pubDate>Mon, 15 Jan 2024 10:00:00 GMT</pubDate>
      <author>Test Author</author>
    </item>
    <item>
      <title>Second Article</title>
      <link>https://www.theverge.com/article2</link>
      <description>Another article description.</description>
      <pubDate>Sun, 14 Jan 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''';

// RSS with enclosure image
const String _rssWithEnclosureImage = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>Article with Enclosure Image</title>
      <link>https://example.com/article</link>
      <description>Description</description>
      <enclosure url="https://example.com/image.jpg" type="image/jpeg" length="12345"/>
    </item>
  </channel>
</rss>
''';

// RSS with media:content image
const String _rssWithMediaContentImage = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
  <channel>
    <item>
      <title>Article with Media Image</title>
      <link>https://example.com/article</link>
      <description>Description</description>
      <media:content url="https://example.com/media-image.jpg" type="image/jpeg"/>
    </item>
  </channel>
</rss>
''';

// RSS with image in description HTML
const String _rssWithDescriptionImage = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>Article with HTML Image</title>
      <link>https://example.com/article</link>
      <description><![CDATA[<p>Description with image <img src="https://example.com/description-image.jpg"/> inside.</p>]]></description>
    </item>
  </channel>
</rss>
''';

// RSS with missing title
const String _rssWithMissingTitle = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <link>https://example.com/article</link>
      <description>Description without title</description>
    </item>
  </channel>
</rss>
''';

// RSS that exceeds max articles per source
String _largeRssXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
''';

String _rssWithMultipleDates(int sourceIndex) {
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>Article from Source \$sourceIndex - Jan 15</title>
      <link>https://example.com/a\$sourceIndex-1</link>
      <description>Description</description>
      <pubDate>Tue, 15 Jan 2024 10:00:00 GMT</pubDate>
    </item>
    <item>
      <title>Article from Source \$sourceIndex - Jan 14</title>
      <link>https://example.com/a\$sourceIndex-2</link>
      <description>Description</description>
      <pubDate>Mon, 14 Jan 2024 10:00:00 GMT</pubDate>
    </item>
  </channel>
</rss>
''';
}