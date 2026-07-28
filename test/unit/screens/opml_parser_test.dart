import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';

// Mirror of _parseOpmlUrls in sources_screen.dart — kept testable.
Set<String> parseOpmlUrls(String opmlText) {
  final urls = <String>{};
  try {
    // Use the same regex fallback as the screen so unit tests hit the
    // same parse logic without UI plumbing.
    final xmlUrlRe = RegExp(r'xmlUrl="([^"]+)"');
    for (final m in xmlUrlRe.allMatches(opmlText)) {
      urls.add(m.group(1)!);
    }
  } catch (_) {}
  return urls;
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

    test('canonical sources include known URLs that OPML would target', () {
      // Make sure at least some of the canonical URLs match what users
      // would import from a typical OPML file (Verge, BBC, Ars).
      final canonicalUrls =
          RssFeedService.predefinedSources.map((s) => s.url).toList();
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
}
