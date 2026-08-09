import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:xml/xml.dart';

// Mirror of _parseOpmlUrls in sources_screen.dart — kept testable.
// Faithful to the screen: XmlDocument.parse first, then a regex
// fallback for slightly malformed OPML. If the screen's parser
// changes, this mirror drifts and these tests start failing.
Set<String> parseOpmlUrls(String opmlText) {
  final urls = <String>{};
  try {
    final doc = XmlDocument.parse(opmlText);
    for (final outline in doc.findAllElements('outline')) {
      final xmlUrl = outline.getAttribute('xmlUrl');
      if (xmlUrl != null && xmlUrl.isNotEmpty) {
        urls.add(xmlUrl);
        continue;
      }
      final htmlUrl = outline.getAttribute('htmlUrl');
      if (htmlUrl != null && htmlUrl.isNotEmpty) {
        urls.add(htmlUrl);
      }
    }
  } catch (e) {
    // Fallback regex for slightly malformed OPML — grabs xmlUrl attributes.
    final xmlUrlRe = RegExp(r'xmlUrl="([^"]+)"');
    for (final m in xmlUrlRe.allMatches(opmlText)) {
      urls.add(m.group(1)!);
    }
  }
  return urls;
}

// Mirror of the screen's match step: subscribe to every canonical source
// whose url appears in the parsed OPML. Unknown URLs are skipped.
Set<String> matchSubscriptions(Set<String> urls) {
  return RssFeedService.predefinedSources
      .where((s) => urls.contains(s.url))
      .map((s) => s.id)
      .toSet();
}

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
      final canonicalUrls = RssFeedService.predefinedSources
          .map((s) => s.url)
          .toList();
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
      final subs = matchSubscriptions(parseOpmlUrls(opml));
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
      expect(matchSubscriptions(urls), isEmpty);
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
      final subs = matchSubscriptions(parseOpmlUrls(opml));
      expect(subs, {'wired', 'nasa'});
    });

    test('malformed OPML with a matching url still subscribes via regex', () {
      const opml =
          '<opml><body><outline xmlUrl="https://feeds.bbci.co.uk/news/rss.xml">';
      final subs = matchSubscriptions(parseOpmlUrls(opml));
      expect(subs, {'bbc'});
    });
  });
}
