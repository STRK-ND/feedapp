import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/article.dart';
import '../models/rss_source.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/error_handler.dart';

/// RSS Feed Service for fetching and parsing RSS feeds
class RssFeedService {
  RssFeedService._();

  /// Predefined RSS sources as a list (for iteration)
  static final List<RssSource> predefinedSources = [
    // Tech
    RssSource(
      id: 'techcrunch',
      name: 'TechCrunch',
      url: 'https://techcrunch.com/feed/',
      category: 'Tech',
      color: AppColors.techPrimary,
      icon: Icons.computer,
    ),
    RssSource(
      id: 'verge',
      name: 'The Verge',
      url: 'https://www.theverge.com/rss/index.xml',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.devices,
    ),
    // News
    RssSource(
      id: 'bbc',
      name: 'BBC World',
      url: 'https://feeds.bbci.co.uk/news/rss.xml',
      category: 'News',
      color: AppColors.newsPrimary,
      icon: Icons.public,
    ),
    RssSource(
      id: 'cnn',
      name: 'CNN Top Stories',
      url: 'https://rss.cnn.com/rss/cnn_topstories.rss',
      category: 'News',
      color: AppColors.newsSecondary,
      icon: Icons.article_rounded,
    ),

    // Science
    RssSource(
      id: 'sciencedaily',
      name: 'Science Daily',
      url: 'https://www.sciencedaily.com/rss/top.xml',
      category: 'Science',
      color: AppColors.sciencePrimary,
      icon: Icons.science_rounded,
    ),

    // Sports
    RssSource(
      id: 'espn',
      name: 'ESPN Top',
      url: 'https://www.espn.com/espn/rss/news',
      category: 'Sports',
      color: AppColors.sportsPrimary,
      icon: Icons.sports,
    ),

    // Entertainment
    RssSource(
      id: 'variety',
      name: 'Variety',
      url: 'https://variety.com/feed/',
      category: 'Entertainment',
      color: AppColors.entertainmentPrimary,
      icon: Icons.theaters_rounded,
    ),
  ];

  /// Predefined RSS sources as a Map for O(1) lookups by ID
  static final Map<String, RssSource> sourcesById = {
    for (var source in predefinedSources) source.id: source,
  };

  /// Fetch articles from a single RSS source
  static Future<List<Article>> fetchArticles(RssSource source) async {
    debugPrint('[RSS] Fetching from ${source.name} (${source.url})');
    try {
      final response = await http
          .get(Uri.parse(source.url))
          .timeout(
            const Duration(seconds: AppConfig.rssTimeoutSeconds),
      );

      debugPrint('[RSS] ${source.name}: HTTP ${response.statusCode}');
      if (response.statusCode == 200) {
        final articles = _parseRssXml(response.body, source);
        debugPrint('[RSS] ${source.name}: Parsed ${articles.length} articles');
        return articles;
      }

      ErrorHandler.logError(
        'HTTP ${response.statusCode} for ${source.name}',
        severity: ErrorSeverity.medium,
      );
      return [];
    } catch (e) {
      debugPrint('[RSS] ERROR fetching ${source.name}: $e');
      ErrorHandler.logError(
        'Error fetching ${source.name}',
        error: e,
        severity: ErrorSeverity.high,
      );
      return [];
    }
  }

  /// Parse RSS XML content into articles
  static List<Article> _parseRssXml(String xmlString, RssSource source) {
    // Security: Validate XML size before parsing
    if (xmlString.length > AppConfig.maxXmlSizeBytes) {
      ErrorHandler.logError(
        'RSS feed exceeds size limit: ${source.name}',
        severity: ErrorSeverity.high,
      );
      return [];
    }

    try {
      final document = XmlDocument.parse(xmlString);
      final articles = <Article>[];

      final items = document.findAllElements('item').take(AppConfig.maxArticlesPerSource);

      for (final item in items) {
        try {
          // Use findElements on the item's descendants instead of the item itself
          final titleElement = item.descendants.whereType<XmlElement>().where((e) => e.localName == 'title').firstOrNull;
          final linkElement = item.descendants.whereType<XmlElement>().where((e) => e.localName == 'link').firstOrNull;
          final descriptionElement = item.descendants.whereType<XmlElement>().where((e) => e.localName == 'description').firstOrNull;
          final pubDateElement = item.descendants.whereType<XmlElement>().where((e) => e.localName == 'pubDate').firstOrNull;
          final authorElement = item.descendants.whereType<XmlElement>().where((e) => e.localName == 'author').firstOrNull
              ?? item.descendants.whereType<XmlElement>().where((e) => e.localName?.endsWith(':creator') == true).firstOrNull;

          // Image extraction - try multiple common fields
          String? imageUrl = _extractImageUrl(item, descriptionElement, linkElement);

          if (titleElement == null || linkElement == null) continue;

          String description = '';
          if (descriptionElement != null) {
            description = Helpers.stripHtmlTags(descriptionElement.innerText);
          }

          String fullContent = '';
          final contentElement = item.descendants.whereType<XmlElement>().where((e) => e.localName?.endsWith(':encoded') == true).firstOrNull;
          if (contentElement != null) {
            fullContent = contentElement.innerText;
          } else {
            fullContent = description;
          }

          DateTime pubDate = DateTime.now();
          if (pubDateElement != null) {
            pubDate = Helpers.parseDate(pubDateElement.innerText);
          }

          final articleId = linkElement.innerText.hashCode.toString();

          articles.add(Article(
            id: articleId,
            title: Helpers.stripHtmlTags(titleElement.innerText).trim(),
            description: Helpers.truncateText(description, 150),
            fullContent: fullContent,
            link: linkElement.innerText,
            sourceId: source.id,
            sourceName: source.name,
            pubDate: pubDate,
            author: authorElement?.innerText.trim(),
            imageUrl: imageUrl,
          ));
        } catch (e) {
          ErrorHandler.logError('Error parsing article item', error: e);
        }
      }

      return articles;
    } catch (e) {
      ErrorHandler.logError(
        'Error parsing RSS XML for ${source.name}',
        error: e,
        severity: ErrorSeverity.high,
      );
      return [];
    }
  }

  /// Extract image URL from RSS item
  static String? _extractImageUrl(
    dynamic item,
    dynamic descriptionElement,
    dynamic linkElement,
  ) {
    String? imageUrl;

    // Helper function to find element by name in item's descendants
    XmlElement? findElement(XmlElement item, String name) {
      return item.descendants.whereType<XmlElement>().where((e) => e.localName == name).firstOrNull;
    }

    // Helper function to find element by suffix (for namespaced elements like media:content)
    XmlElement? findElementBySuffix(XmlElement item, String suffix) {
      return item.descendants.whereType<XmlElement>().where((e) => e.localName?.endsWith(suffix) == true).firstOrNull;
    }

    // Method 1: enclosure element (most common)
    final enclosureElement = findElement(item, 'enclosure');
    if (enclosureElement != null) {
      final url = enclosureElement.getAttribute('url');
      if (url != null) {
        imageUrl = url;
      }
    }

    // Method 2: media:content element
    if (imageUrl == null) {
      final mediaElement = findElementBySuffix(item, 'content');
      if (mediaElement != null) {
        final url = mediaElement.getAttribute('url');
        if (url != null) {
          imageUrl = url;
        }
      }
    }

    // Method 2.5: media:thumbnail element
    if (imageUrl == null) {
      final thumbnailElement = findElementBySuffix(item, 'thumbnail');
      if (thumbnailElement != null) {
        final url = thumbnailElement.getAttribute('url');
        if (url != null) {
          imageUrl = url;
        }
      }
    }

    // Method 3: description HTML img tags
    if (imageUrl == null && descriptionElement != null) {
      final descriptionText = descriptionElement.innerText;
      imageUrl = _extractFirstImageUrl(descriptionText);
    }

    // Method 4: Try content:encoded for embedded HTML images
    if (imageUrl == null) {
      final contentElement = findElementBySuffix(item, 'encoded');
      if (contentElement != null) {
        final contentText = contentElement.innerText;
        imageUrl = _extractFirstImageUrl(contentText);
      }
    }

    // Method 5: Try to extract ANY URL from description as fallback
    if (imageUrl == null && descriptionElement != null) {
      final descriptionText = descriptionElement.innerText;
      if (descriptionText.isNotEmpty && descriptionText.contains('http')) {
        final urlMatches = RegExp(r'https?://\S+', multiLine: true)
            .allMatches(descriptionText)
            .map((m) => m.group(0)!);

        for (final url in urlMatches) {
          // Skip if it's the main article link
          if (linkElement != null && url == linkElement.innerText) continue;

          // Just accept it - be very lenient to catch any images
          imageUrl = url;
          break;
        }
      }
    }

    // If still no image, try extracting from the full content/encoded
    if (imageUrl == null) {
      final contentElement = findElementBySuffix(item, 'encoded');
      if (contentElement != null) {
        final contentText = contentElement.innerText;
        if (contentText.isNotEmpty && contentText.contains('http')) {
          final urlMatches = RegExp(r'https?://\S+', multiLine: true)
              .allMatches(contentText)
              .map((m) => m.group(0)!);

          for (final url in urlMatches) {
            if (linkElement != null && url == linkElement.innerText) continue;
            imageUrl = url;
            break;
          }
        }
      }
    }

    // Validate the found image URL
    if (imageUrl != null && Helpers.isValidImageUrl(imageUrl)) {
      return imageUrl;
    }

    return null;
  }

  /// Extract first image URL from HTML content
  static String? _extractFirstImageUrl(String htmlContent) {
    if (htmlContent.isEmpty) return null;

    final imgMatches = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', multiLine: true)
        .allMatches(htmlContent)
        .map((m) => m.group(1))
        .whereType<String>();

    if (imgMatches.isNotEmpty) {
      return imgMatches.first;
    }

    return null;
  }

  /// Fetch articles from all sources
  static Future<List<Article>> fetchAllArticles() async {
    debugPrint('[RSS] Fetching from ${predefinedSources.length} sources...');
    final allArticles = <Article>[];

    // Fetch all sources in parallel for speed
    final results = await Future.wait(
      predefinedSources.map((source) => fetchArticles(source)),
      eagerError: false, // Continue even if some sources fail
    );

    // Flatten results
    for (final sourceArticles in results) {
      allArticles.addAll(sourceArticles);
    }

    debugPrint('[RSS] Total articles fetched: ${allArticles.length}');

    // Sort by publication date (newest first)
    allArticles.sort((a, b) => b.pubDate.compareTo(a.pubDate));

    return allArticles;
  }

  /// Get source by ID
  static RssSource? getSourceById(String id) {
    return sourcesById[id];
  }
}
