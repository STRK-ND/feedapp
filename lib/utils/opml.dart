/// OPML import/export helpers.
///
/// Import: parse feed URLs out of an OPML document and match them against
/// the canonical source list. Export: serialize subscribed sources back
/// into a standard OPML 2.0 document other readers can consume.
library;

import 'package:xml/xml.dart';
import '../models/rss_source.dart';

/// Single outline entry from an OPML document with its URL and optional title.
class OpmlEntry {
  final String url;
  final String title;
  const OpmlEntry({required this.url, required this.title});
}

/// Pull every outline entry (URL and title) out of an OPML document.
List<OpmlEntry> parseOpmlEntries(String opmlText) {
  final entries = <OpmlEntry>[];
  final seenUrls = <String>{};
  try {
    final doc = XmlDocument.parse(opmlText);
    for (final outline in doc.findAllElements('outline')) {
      final xmlUrl = outline.getAttribute('xmlUrl');
      final htmlUrl = outline.getAttribute('htmlUrl');
      final url = (xmlUrl != null && xmlUrl.isNotEmpty)
          ? xmlUrl
          : ((htmlUrl != null && htmlUrl.isNotEmpty) ? htmlUrl : null);
      if (url != null && seenUrls.add(url)) {
        final title =
            outline.getAttribute('title') ??
            outline.getAttribute('text') ??
            _hostFromUrl(url);
        entries.add(OpmlEntry(url: url, title: title));
      }
    }
  } catch (_) {
    final xmlUrlRe = RegExp(r'xmlUrl="([^"]+)"');
    for (final m in xmlUrlRe.allMatches(opmlText)) {
      final url = m.group(1)!;
      if (seenUrls.add(url)) {
        entries.add(OpmlEntry(url: url, title: _hostFromUrl(url)));
      }
    }
  }
  return entries;
}

/// Domain of [url] for use as a fallback title when the OPML outline
/// carries neither `title` nor `text`. Empty string when the URL does
/// not parse — callers already handle an empty title.
String _hostFromUrl(String url) {
  try {
    return Uri.parse(url).host;
  } catch (_) {
    return '';
  }
}

/// Pull every xmlUrl (and htmlUrl as fallback) out of an OPML document.
Set<String> parseOpmlUrls(String opmlText) {
  return parseOpmlEntries(opmlText).map((e) => e.url).toSet();
}

/// Match parsed OPML URLs against canonical sources (by [RssSource.url]).
/// Unknown URLs are skipped — only feeds from the canonical list are
/// supported.
Set<String> matchCanonicalSources(Set<String> urls, List<RssSource> canonical) {
  return canonical.where((s) => urls.contains(s.url)).map((s) => s.id).toSet();
}

/// Serialize sources into an OPML 2.0 document. Each source becomes one
/// `<outline>` with both xmlUrl and htmlUrl so any reader can re-import it.
String buildOpmlDocument(
  List<RssSource> sources, {
  String title = 'Subscriptions',
}) {
  final builder = XmlBuilder();
  builder.processing('xml', 'version="1.0" encoding="UTF-8"');
  builder.element(
    'opml',
    attributes: {'version': '2.0'},
    nest: () {
      builder.element(
        'head',
        nest: () {
          builder.element('title', nest: title);
          builder.element(
            'dateCreated',
            nest: DateTime.now().toUtc().toIso8601String(),
          );
        },
      );
      builder.element(
        'body',
        nest: () {
          for (final s in sources) {
            builder.element(
              'outline',
              attributes: {
                'text': s.name,
                'title': s.name,
                'type': 'rss',
                'xmlUrl': s.url,
                if (s.category.isNotEmpty) 'category': s.category,
              },
            );
          }
        },
      );
    },
  );
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}
