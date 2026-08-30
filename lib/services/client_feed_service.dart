/// Client-side fetching and parsing of user-added custom feeds.
///
/// The Cloudflare worker aggregates the canonical source list; custom
/// sources are per-user, so they are fetched and parsed directly on the
/// device. Supports RSS 2.0 and Atom — the two formats the worker's own
/// parser handles — with the same size/timeout caps.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/article.dart';
import '../models/rss_source.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

/// Fetches a single custom feed URL and parses it into [Article]s.
class ClientFeedService {
  final http.Client _httpClient;

  ClientFeedService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Fetch and parse [source]. Returns at most
  /// [AppConfig.maxArticlesPerSource] items; throws on network/format
  /// failure so callers can skip the source without losing the rest.
  Future<List<Article>> fetchSourceArticles(RssSource source) async {
    debugPrint('[ClientFeed] Fetching ${source.url}');

    final response = await _httpClient
        .get(
          Uri.parse(source.url),
          headers: {
            'User-Agent': 'CuratedFeeds/1.0 (+https://curatedfeeds.app)',
            'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml',
          },
        )
        .timeout(const Duration(seconds: AppConfig.rssTimeoutSeconds));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} for ${source.url}');
    }
    if (response.bodyBytes.length > AppConfig.maxXmlSizeBytes) {
      throw Exception('Feed too large: ${source.url}');
    }

    return parseFeed(response.body, source);
  }

  /// Parse an RSS 2.0 or Atom document. Pure (no I/O) so tests can pin
  /// the format contract directly.
  List<Article> parseFeed(String xmlText, RssSource source) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlText);
    } catch (e) {
      throw FormatException('Invalid XML from ${source.url}: $e');
    }

    // Atom roots <feed>; everything else with <item> is treated as RSS.
    final isAtom = doc.findAllElements('feed').isNotEmpty;
    final elements = isAtom
        ? doc.findAllElements('entry').toList()
        : doc.findAllElements('item').toList();

    final articles = <Article>[];
    for (final el in elements.take(AppConfig.maxArticlesPerSource)) {
      try {
        final article = isAtom ? _fromAtom(el, source) : _fromRss(el, source);
        if (article != null) articles.add(article);
      } catch (e) {
        // Skip malformed entries rather than dropping the whole feed.
        unawaited(
          ErrorHandler.logError(
            'Skipping malformed entry in ${source.url}',
            error: e,
          ),
        );
      }
    }
    return articles;
  }

  Article? _fromRss(XmlElement item, RssSource source) {
    final title = _textOf(item, 'title');
    var link = _textOf(item, 'link');
    link ??= _attrOfNested(item, 'guid'); // rare fallback
    if (title == null || title.isEmpty || link == null || link.isEmpty) {
      return null;
    }

    final rawDescription =
        _textOf(item, 'description') ??
        _textOf(item, 'content:encoded') ??
        '';
    final description = stripHtml(rawDescription);

    final pubDate =
        _parseDate(_textOf(item, 'pubDate')) ??
        _parseDate(_textOf(item, 'dc:date')) ??
        DateTime.now();

    final author = _textOf(item, 'author') ?? _textOf(item, 'dc:creator');

    return _build(
      source: source,
      title: title,
      link: link,
      description: description,
      pubDate: pubDate,
      author: author,
      imageUrl: _imageUrlFrom(item),
    );
  }

  Article? _fromAtom(XmlElement entry, RssSource source) {
    final title = _textOf(entry, 'title');
    var link = _atomAlternateLink(entry);
    link ??= _textOf(entry, 'id');
    if (title == null || title.isEmpty || link == null || link.isEmpty) {
      return null;
    }

    final rawBody =
        _textOf(entry, 'content') ?? _textOf(entry, 'summary') ?? '';
    final description = stripHtml(rawBody);

    final pubDate =
        _parseDate(_textOf(entry, 'published')) ??
        _parseDate(_textOf(entry, 'updated')) ??
        DateTime.now();

    final author = _nestedText(entry, ['author', 'name']);

    return _build(
      source: source,
      title: title,
      link: link,
      description: description,
      pubDate: pubDate,
      author: author,
      imageUrl: _imageUrlFrom(entry),
    );
  }

  Article _build({
    required RssSource source,
    required String title,
    required String link,
    required String description,
    required DateTime pubDate,
    String? author,
    String? imageUrl,
  }) {
    return Article(
      id: '${source.id}-${_stableHash(link)}',
      title: title,
      description: description,
      fullContent: description,
      link: link,
      sourceId: source.id,
      sourceName: source.name,
      pubDate: pubDate.toUtc(),
      author: author,
      imageUrl: imageUrl,
      sourceCategory: source.category,
      sourceColor:
          '#${source.color.toARGB32().toRadixString(16).substring(2)}',
      sourceIcon: 'rss_feed',
    );
  }

  /// First direct child element matching [name] (qualified name allowed).
  String? _textOf(XmlElement parent, String name) {
    for (final el in parent.children.whereType<XmlElement>()) {
      if (el.name.qualified == name) {
        return el.innerText.trim();
      }
    }
    return null;
  }

  String? _nestedText(XmlElement parent, List<String> path) {
    XmlElement? current = parent;
    for (final name in path) {
      final found = current?.children
          .whereType<XmlElement>()
          .where((el) => el.name.qualified == name)
          .firstOrNull;
      if (found == null) return null;
      current = found;
    }
    return current?.innerText.trim();
  }

  String? _attrOfNested(XmlElement parent, String name) {
    for (final el in parent.children.whereType<XmlElement>()) {
      if (el.name.qualified == name) {
        final text = el.innerText.trim();
        if (text.startsWith('http')) return text;
      }
    }
    return null;
  }

  /// Atom <link>: prefer rel="alternate" or no rel, else first href.
  String? _atomAlternateLink(XmlElement entry) {
    final links = entry.children
        .whereType<XmlElement>()
        .where((el) => el.name.qualified == 'link')
        .toList();
    if (links.isEmpty) return null;
    for (final l in links) {
      final rel = l.getAttribute('rel');
      final href = l.getAttribute('href');
      if ((rel == null || rel == 'alternate') &&
          href != null &&
          href.isNotEmpty) {
        return href;
      }
    }
    return links.first.getAttribute('href');
  }

  /// Image hunt mirrors the worker: media:content → enclosure → <img>.
  String? _imageUrlFrom(XmlElement item) {
    for (final el in item.descendantElements) {
      if (el.name.qualified == 'media:content' ||
          el.name.qualified == 'media:thumbnail') {
        final url = el.getAttribute('url');
        if (url != null && url.isNotEmpty) return url;
      }
      if (el.name.qualified == 'enclosure') {
        final url = el.getAttribute('url');
        final type = el.getAttribute('type') ?? '';
        if (url != null &&
            url.isNotEmpty &&
            (type.startsWith('image/') ||
                RegExp(r'\.(jpe?g|png|webp|gif)', caseSensitive: false)
                    .hasMatch(url))) {
          return url;
        }
      }
    }
    // Inline <img src> inside HTML descriptions.
    final html = item.innerText;
    final m = RegExp(r'<img\b[^>]*src="([^"]+)"', caseSensitive: false)
        .firstMatch(html);
    return m?.group(1);
  }

  /// RFC-2822 ("Tue, 28 Jul 2026 18:11:00 GMT"), ISO-8601, or null.
  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;

    // RFC-2822: day-of-week, DD Mon YYYY HH:MM:SS ±ZZZZ
    final m = RegExp(
      r'(\d{1,2})\s+(\w{3})\w*\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Z]{3,5})?',
    ).firstMatch(raw);
    if (m == null) return null;

    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    final month = months[m.group(2)!.toLowerCase()];
    if (month == null) return null;

    var utc = DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.tryParse(m.group(6) ?? '0') ?? 0,
    );

    final tz = m.group(7);
    if (tz != null && tz.startsWith(RegExp(r'[+-]\d{4}'))) {
      final sign = tz[0] == '-' ? -1 : 1;
      final hours = int.parse(tz.substring(1, 3));
      final minutes = int.parse(tz.substring(3, 5));
      utc = utc.subtract(Duration(hours: sign * hours, minutes: sign * minutes));
    } else if (tz != null) {
      const namedOffsets = {
        'GMT': 0, 'UTC': 0, 'UT': 0,
        'EST': -5, 'EDT': -4, 'CST': -6, 'CDT': -5,
        'MST': -7, 'MDT': -6, 'PST': -8, 'PDT': -7,
        'BST': 1, 'IST': 5.5, 'CET': 1, 'CEST': 2,
      };
      final off = namedOffsets[tz.toUpperCase()];
      if (off != null) {
        final hours = off.truncate();
        final minutes = ((off - hours) * 60).round();
        utc = utc.subtract(Duration(hours: hours, minutes: minutes));
      }
    }
    return utc;
  }

  String stripHtml(String input) {
    var s = input
        .replaceAll(RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>'), r'$1')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&hellip;', '…')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.length > 2000) s = '${s.substring(0, 2000)}…';
    return s;
  }

  /// Deterministic across runs (unlike String.hashCode).
  static String _stableHash(String input) {
    var h = 0;
    for (final cu in input.codeUnits) {
      h = ((h << 5) - h + cu) & 0x3FFFFFFF;
    }
    return h.toRadixString(36);
  }
}
