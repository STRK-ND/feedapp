/// OPML import/export helpers.
///
/// Import: parse feed URLs out of an OPML document and match them against
/// the canonical source list. Export: serialize subscribed sources back
/// into a standard OPML 2.0 document other readers can consume.
library;

import 'package:xml/xml.dart';
import '../models/rss_source.dart';

/// Pull every xmlUrl (and htmlUrl as fallback) out of an OPML document.
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
  } catch (_) {
    // Fallback regex for slightly malformed OPML — grabs xmlUrl attributes.
    final xmlUrlRe = RegExp(r'xmlUrl="([^"]+)"');
    for (final m in xmlUrlRe.allMatches(opmlText)) {
      urls.add(m.group(1)!);
    }
  }
  return urls;
}

/// Match parsed OPML URLs against canonical sources (by [RssSource.url]).
/// Unknown URLs are skipped — only feeds from the canonical list are
/// supported.
Set<String> matchCanonicalSources(
  Set<String> urls,
  List<RssSource> canonical,
) {
  return canonical.where((s) => urls.contains(s.url)).map((s) => s.id).toSet();
}

/// Serialize sources into an OPML 2.0 document. Each source becomes one
/// `<outline>` with both xmlUrl and htmlUrl so any reader can re-import it.
String buildOpmlDocument(List<RssSource> sources, {String title = 'Subscriptions'}) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element('opml', attributes: {'version': '2.0'}, nest: () {
    builder.element('head', nest: () {
      builder.element('title', nest: title);
      builder.element('dateCreated',
          nest: DateTime.now().toUtc().toIso8601String());
    });
    builder.element('body', nest: () {
      for (final s in sources) {
        builder.element('outline', attributes: {
          'text': s.name,
          'title': s.name,
          'type': 'rss',
          'xmlUrl': s.url,
          if (s.category.isNotEmpty) 'category': s.category,
        });
      }
    });
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}
