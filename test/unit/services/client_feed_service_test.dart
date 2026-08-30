import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:curatedfeeds/models/rss_source.dart';
import 'package:curatedfeeds/services/client_feed_service.dart';

void main() {
  // RssSource.custom is a factory with a body — not const.
  final source = RssSource.custom(
    id: 'custom-abc',
    name: 'My Blog',
    url: 'https://example.com/feed.xml',
  );

  ClientFeedService serviceWith(String body, {int status = 200}) {
    return ClientFeedService(
      httpClient: MockClient(
        (request) async => http.Response(body, status),
      ),
    );
  }

  group('ClientFeedService.parseFeed — RSS 2.0', () {
    const rss = '''
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>My Blog</title>
        <item>
          <title>First post</title>
          <link>https://example.com/1</link>
          <description><![CDATA[<p>Hello <b>world</b> &amp; more</p>]]></description>
          <pubDate>Tue, 28 Jul 2026 18:11:00 GMT</pubDate>
          <enclosure url="https://img.example.com/1.jpg" type="image/jpeg" length="100"/>
        </item>
        <item>
          <title>Second post</title>
          <link>https://example.com/2</link>
          <description>Plain text summary</description>
          <pubDate>Tue, 27 Jul 2026 09:30:00 +0530</pubDate>
        </item>
        <item>
          <description>No title or link here</description>
        </item>
      </channel>
    </rss>
    ''';

    test('parses items, strips HTML, skips entries without title/link', () {
      final articles = serviceWith(rss).parseFeed(rss, source);

      expect(articles.length, 2);
      expect(articles[0].title, 'First post');
      expect(articles[0].description, 'Hello world & more');
      expect(articles[0].sourceId, 'custom-abc');
      expect(articles[0].sourceName, 'My Blog');
      expect(articles[0].imageUrl, 'https://img.example.com/1.jpg');
    });

    test('ids are stable across parses and unique per link', () {
      final a = serviceWith(rss).parseFeed(rss, source);
      final b = serviceWith(rss).parseFeed(rss, source);

      expect(a[0].id, b[0].id);
      expect(a[1].id, b[1].id);
      expect(a[0].id, isNot(equals(a[1].id)));
      expect(a[0].id.startsWith('custom-abc-'), isTrue);
    });

    test('parses RFC-2822 and offset date forms', () {
      final articles = serviceWith(rss).parseFeed(rss, source);
      // Tue, 28 Jul 2026 18:11:00 GMT
      expect(articles[0].pubDate.toUtc().hour, 18);
      // 09:30 +0530 == 04:00 UTC
      expect(articles[1].pubDate.toUtc().hour, 4);
    });

    test('media:content image preferred over enclosure', () {
      // Inject media:content as the first child of the first <item>, ahead
      // of its <enclosure> — mirrors real feeds that carry both.
      final withMedia = rss.replaceFirst(
        '<item>',
        '<item><media:content url="https://img.example.com/media.png"/>',
      );
      final articles = serviceWith(withMedia).parseFeed(withMedia, source);
      expect(articles.first.imageUrl, 'https://img.example.com/media.png');
    });
  });

  group('ClientFeedService.parseFeed — Atom', () {
    const atom = '''
    <?xml version="1.0" encoding="utf-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Atom Blog</title>
      <entry>
        <title>Atom entry</title>
        <link rel="alternate" href="https://example.com/a1"/>
        <summary>Notes &amp; thoughts on things</summary>
        <published>2026-07-28T18:11:00Z</published>
        <author><name>Jane Doe</name></author>
      </entry>
    </feed>
    ''';

    test('parses alternate link, author, ISO date', () {
      final articles = serviceWith(atom).parseFeed(atom, source);

      expect(articles.length, 1);
      expect(articles[0].title, 'Atom entry');
      expect(articles[0].link, 'https://example.com/a1');
      expect(articles[0].author, 'Jane Doe');
      // Entities decode (&amp; → &); HTML tags in feed copy are stripped.
      expect(articles[0].description, 'Notes & thoughts on things');
      expect(articles[0].pubDate.year, 2026);
      expect(articles[0].pubDate.month, 7);
    });
  });

  group('ClientFeedService.fetchSourceArticles', () {
    test('throws on non-200', () async {
      final service = serviceWith('nope', status: 500);
      await expectLater(
        service.fetchSourceArticles(source),
        throwsException,
      );
    });

    test('caps items at maxArticlesPerSource', () async {
      const item = '<item><title>t</title>'
          '<link>https://example.com/%ID%</link></item>';
      final body = '<rss><channel>${List.generate(
        40,
        (i) => item.replaceAll('%ID%', '$i'),
      ).join()}</channel></rss>';

      final service = ClientFeedService(
        httpClient: MockClient((request) async => http.Response(body, 200)),
      );
      final articles = await service.fetchSourceArticles(source);
      expect(articles.length, 20); // AppConfig.maxArticlesPerSource
    });
  });

  group('RssSource custom helpers', () {
    test('stableIdForUrl is deterministic and URL-sensitive', () {
      expect(
        RssSource.stableIdForUrl('https://a.dev/feed'),
        RssSource.stableIdForUrl('https://a.dev/feed'),
      );
      expect(
        RssSource.stableIdForUrl('https://a.dev/feed'),
        isNot(RssSource.stableIdForUrl('https://b.dev/feed')),
      );
    });

    test('json roundtrip preserves identity fields', () {
      final s = RssSource.custom(
        id: 'custom-x',
        name: 'N',
        url: 'https://n.example/feed',
      );
      final back = RssSource.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.name, s.name);
      expect(back.url, s.url);
      expect(back.category, s.category);
      expect(back.color, s.color);
      expect(back.icon.codePoint, s.icon.codePoint);
    });
  });
}
