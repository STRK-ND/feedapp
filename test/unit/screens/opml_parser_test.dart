import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:curatedfeeds/utils/opml.dart';

// Tests exercise the real lib/utils/opml.dart implementation — no mirror.
// parseOpmlUrls / matchCanonicalSources / buildOpmlDocument are public.

/// The registry's bundled seed list (worker list not fetched in unit tests).
final registrySources = RssFeedService().sources;

void main() {
  group('OPML parsing', () {
    test('extracts single xmlUrl from minimal opml', () {
      const opml = '''
      <?xml version="1.0"?>
      <opml version="2.0">
        <body>
          <outline text="Verge" xmlUrl="https://www.theverge.com/rss/index.xml"/>
        </body>
      </opml>
      ''';
      final urls = parseOpmlUrls(opml);
      expect(urls, contains('https://www.theverge.com/rss/index.xml'));
    });

    test('extracts multiple xmlUrls', () {
      const opml = '''
      <opml version="2.0">
        <body>
          <outline xmlUrl="https://feeds.bbci.co.uk/news/rss.xml"/>
          <outline xmlUrl="https://www.theverge.com/rss/index.xml"/>
          <outline xmlUrl="https://feeds.arstechnica.com/arstechnica/index"/>
        </body>
      </opml>
      ''';
      final urls = parseOpmlUrls(opml);
      expect(urls.length, 3);
      expect(urls, contains('https://feeds.bbci.co.uk/news/rss.xml'));
    });

    test('returns empty set for empty string', () {
      expect(parseOpmlUrls(''), isEmpty);
    });

    test('falls back to regex for malformed (unclosed) opml', () {
      const opml =
          '<opml><body><outline xmlUrl="https://feeds.bbci.co.uk/news/rss.xml">';
      final urls = parseOpmlUrls(opml);
      expect(urls, contains('https://feeds.bbci.co.uk/news/rss.xml'));
    });

    test('uses htmlUrl only when xmlUrl is absent', () {
      const opml = '''
      <opml version="2.0">
        <body>
          <outline text="BBC" htmlUrl="https://www.bbc.com/news"/>
        </body>
      </opml>
      ''';
      final urls = parseOpmlUrls(opml);
      expect(urls, {'https://www.bbc.com/news'});
    });

    test('canonical sources include known URLs that OPML would target', () {
      // Make sure at least some of the canonical URLs match what users
      // would import from a typical OPML file (Verge, BBC, Ars).
      final canonicalUrls = registrySources.map((s) => s.url).toList();
      expect(
        canonicalUrls,
        containsAll(<String>[
          'https://www.theverge.com/rss/index.xml',
          'https://feeds.bbci.co.uk/news/rss.xml',
          'https://feeds.arstechnica.com/arstechnica/index',
        ]),
      );
    });
  });

  group('OPML import → subscriptions', () {
    test('valid OPML whose xmlUrl matches a built-in source subscribes it', () {
      const opml = '''
      <opml version="2.0">
        <body>
          <outline text="The Verge" xmlUrl="https://www.theverge.com/rss/index.xml"/>
        </body>
      </opml>
      ''';
      final subs = matchCanonicalSources(parseOpmlUrls(opml), registrySources);
      expect(subs, {'verge'});
    });

    test('unknown URLs are skipped — no subscription created', () {
      const opml = '''
      <opml version="2.0">
        <body>
          <outline text="Random blog" xmlUrl="https://example.com/feed.xml"/>
        </body>
      </opml>
      ''';
      final urls = parseOpmlUrls(opml);
      expect(urls, {'https://example.com/feed.xml'});
      expect(matchCanonicalSources(urls, registrySources), isEmpty);
    });

    test('mixed OPML subscribes only the matching subset', () {
      const opml = '''
      <opml version="2.0">
        <body>
          <outline text="Wired" xmlUrl="https://www.wired.com/feed/rss"/>
          <outline text="Private feed" xmlUrl="https://secret.example.com/rss"/>
          <outline text="NASA" xmlUrl="https://www.nasa.gov/rss/dyn/breaking_news.rss"/>
        </body>
      </opml>
      ''';
      final subs = matchCanonicalSources(parseOpmlUrls(opml), registrySources);
      expect(subs, {'wired', 'nasa'});
    });

    test('malformed OPML with a matching url still subscribes via regex', () {
      const opml =
          '<opml><body><outline xmlUrl="https://feeds.bbci.co.uk/news/rss.xml">';
      final subs = matchCanonicalSources(parseOpmlUrls(opml), registrySources);
      expect(subs, {'bbc'});
    });
  });

  group('OPML export', () {
    test('built document round-trips back into subscriptions', () {
      final sources = registrySources
          .where((s) => {'verge', 'bbc'}.contains(s.id))
          .toList();

      final xml = buildOpmlDocument(sources);
      final urls = parseOpmlUrls(xml);
      final subs = matchCanonicalSources(urls, registrySources);

      expect(subs, {'verge', 'bbc'});
    });

    test('document carries name, type=rss and category per source', () {
      final verge = registrySources.firstWhere((s) => s.id == 'verge');
      final xml = buildOpmlDocument([verge]);

      expect(xml, contains('<opml version="2.0">'));
      expect(xml, contains('text="${verge.name}"'));
      expect(xml, contains('type="rss"'));
      expect(xml, contains('xmlUrl="${verge.url}"'));
      expect(xml, contains('category="${verge.category}"'));
    });

    test('empty source list still yields a valid empty body', () {
      final xml = buildOpmlDocument([]);
      expect(parseOpmlUrls(xml), isEmpty);
      // XmlBuilder self-closes an empty element: <body/>
      expect(xml, contains('<body'));
    });
  });
}
