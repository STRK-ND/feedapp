import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/article.dart';
import '../models/rss_source.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/error_handler.dart';

/// RSS Feed Service for fetching and parsing RSS feeds
/// Now uses dependency injection for better testability
class RssFeedService {
  final http.Client _httpClient;

  RssFeedService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Predefined RSS sources as a list (for iteration) - filtered to image-friendly sources
  static final List<RssSource> predefinedSources = [
    // Tech
    RssSource(
      id: 'verge',
      name: 'The Verge',
      url: 'https://www.theverge.com/rss/index.xml',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.devices,
    ),
    RssSource(
      id: 'wired',
      name: 'Wired',
      url: 'https://www.wired.com/feed/rss',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.memory,
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
    // Science
    RssSource(
      id: 'newscientist',
      name: 'New Scientist',
      url: 'https://www.newscientist.com/feed/home/',
      category: 'Science',
      color: AppColors.scienceSecondary,
      icon: Icons.biotech,
    ),
    // Sports - using ESPN as Bleacher Report URL is broken
    RssSource(
      id: 'skysports',
      name: 'Sky Sports',
      url: 'https://www.skysports.com/rss/12040',
      category: 'Sports',
      color: AppColors.sportsSecondary,
      icon: Icons.sports_soccer,
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
    // Tech - Additional sources
    RssSource(
      id: 'arstechnica',
      name: 'Ars Technica',
      url: 'https://feeds.arstechnica.com/arstechnica/index',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.computer,
    ),
    RssSource(
      id: 'techcrunch',
      name: 'TechCrunch',
      url: 'https://techcrunch.com/feed/',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.rocket_launch,
    ),
    RssSource(
      id: 'engadget',
      name: 'Engadget',
      url: 'https://www.engadget.com/rss.xml',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.devices_other,
    ),
    // News - Additional sources
    RssSource(
      id: 'guardian',
      name: 'The Guardian',
      url: 'https://www.theguardian.com/world/rss',
      category: 'News',
      color: AppColors.newsPrimary,
      icon: Icons.newspaper,
    ),
    // Gaming
    RssSource(
      id: 'ign',
      name: 'IGN',
      url: 'https://feeds.ign.com/ign/games-all',
      category: 'Gaming',
      color: AppColors.gamingSecondary,
      icon: Icons.sports_esports,
    ),
    // Science - Additional sources
    RssSource(
      id: 'nasa',
      name: 'NASA',
      url: 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
      category: 'Science',
      color: AppColors.scienceSecondary,
      icon: Icons.rocket,
    ),
  ];

  /// Predefined RSS sources as a Map for O(1) lookups by ID
  static final Map<String, RssSource> sourcesById = {
    for (var source in predefinedSources) source.id: source,
  };

  /// Helper to safely get text from XmlElement
  static String _getElementText(XmlElement? element) {
    if (element == null) return '';
    try {
      // Use innerText property which should work on XmlElement
      return element.innerText;
    } catch (e) {
      // Fallback: manually get text content from children
      return element.children
          .whereType<XmlText>()
          .map((e) => e.value)
          .join('');
    }
  }

  /// Fetch articles from a single RSS source
  Future<List<Article>> fetchArticles(RssSource source) async {
    debugPrint('[RSS] Fetching from ${source.name} (${source.url})');
    try {
      final response = await _httpClient
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
  List<Article> _parseRssXml(String xmlString, RssSource source) {
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
          // Find elements safely
          final titleElement = _findElement(item, 'title');
          final linkElement = _findElement(item, 'link');
          final descriptionElement = _findElement(item, 'description');
          final pubDateElement = _findElement(item, 'pubDate');
          final authorElement = _findElement(item, 'author')
              ?? _findElementBySuffix(item, 'creator');

          // Image extraction - try multiple common fields
          String? imageUrl = _extractImageUrl(item, descriptionElement, linkElement);

          if (titleElement == null || linkElement == null) continue;

          // Get text using safe helper
          String titleText = _getElementText(titleElement);
          String linkText = _getElementText(linkElement);
          String descriptionText = _getElementText(descriptionElement);
          String pubDateText = _getElementText(pubDateElement);
          String authorText = _getElementText(authorElement);

          String description = Helpers.stripHtmlTags(descriptionText);
          String fullContent = '';

          // Try to get content:encoded
          final contentElement = _findElementBySuffix(item, 'encoded');
          if (contentElement != null) {
            fullContent = _getElementText(contentElement);
          } else {
            fullContent = description;
          }

          DateTime pubDate = DateTime.now();
          if (pubDateText.isNotEmpty) {
            pubDate = Helpers.parseDate(pubDateText);
          }

          final articleId = Article.makeId(source.id, linkText.hashCode.toString());

          articles.add(Article(
            id: articleId,
            title: Helpers.stripHtmlTags(titleText).trim(),
            description: Helpers.truncateText(description, 150),
            fullContent: fullContent,
            link: linkText,
            sourceId: source.id,
            sourceName: source.name,
            pubDate: pubDate,
            author: authorText.isNotEmpty ? authorText.trim() : null,
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

  /// Helper to find element by name in item's descendants
  static XmlElement? _findElement(XmlElement item, String name) {
    return item.descendants.whereType<XmlElement>().where((e) => e.localName == name).firstOrNull;
  }

  /// Helper to find element by suffix (for namespaced elements like media:content)
  static XmlElement? _findElementBySuffix(XmlElement item, String suffix) {
    return item.descendants.whereType<XmlElement>().where((e) => e.localName.endsWith(suffix)).firstOrNull;
  }

  /// Extract image URL from RSS item
  static String? _extractImageUrl(
    XmlElement item,
    XmlElement? descriptionElement,
    XmlElement? linkElement,
  ) {
    String? imageUrl;

    // Method 1: enclosure element (most common)
    final enclosureElement = _findElement(item, 'enclosure');
    if (enclosureElement != null) {
      final url = enclosureElement.getAttribute('url');
      if (url != null) {
        imageUrl = url;
      }
    }

    // Method 2: media:content element
    if (imageUrl == null) {
      final mediaElement = _findElementBySuffix(item, 'content');
      if (mediaElement != null) {
        final url = mediaElement.getAttribute('url');
        if (url != null) {
          imageUrl = url;
        }
      }
    }

    // Method 2.5: media:thumbnail element
    if (imageUrl == null) {
      final thumbnailElement = _findElementBySuffix(item, 'thumbnail');
      if (thumbnailElement != null) {
        final url = thumbnailElement.getAttribute('url');
        if (url != null) {
          imageUrl = url;
        }
      }
    }

    // Method 3: description HTML img tags
    if (imageUrl == null && descriptionElement != null) {
      final descriptionText = _getElementText(descriptionElement);
      imageUrl = _extractFirstImageUrl(descriptionText);
    }

    // Method 4: Try content:encoded for embedded HTML images
    if (imageUrl == null) {
      final contentElement = _findElementBySuffix(item, 'encoded');
      if (contentElement != null) {
        final contentText = _getElementText(contentElement);
        imageUrl = _extractFirstImageUrl(contentText);
      }
    }

    // Method 5: Try to extract ANY URL from description as fallback
    if (imageUrl == null && descriptionElement != null) {
      final descriptionText = _getElementText(descriptionElement);
      final linkText = linkElement != null ? _getElementText(linkElement) : '';
      if (descriptionText.isNotEmpty && descriptionText.contains('http')) {
        final urlMatches = RegExp(r'https?://\S+', multiLine: true)
            .allMatches(descriptionText)
            .map((m) => m.group(0)!);

        for (final url in urlMatches) {
          // Skip if it's the main article link
          if (linkText.isNotEmpty && url == linkText) continue;
          // Just accept it - be very lenient to catch any images
          imageUrl = url;
          break;
        }
      }
    }

    // If still no image, try extracting from the full content/encoded
    if (imageUrl == null) {
      final contentElement = _findElementBySuffix(item, 'encoded');
      if (contentElement != null) {
        final contentText = _getElementText(contentElement);
        final linkText = linkElement != null ? _getElementText(linkElement) : '';
        if (contentText.isNotEmpty && contentText.contains('http')) {
          final urlMatches = RegExp(r'https?://\S+', multiLine: true)
              .allMatches(contentText)
              .map((m) => m.group(0)!);

          for (final url in urlMatches) {
            if (linkText.isNotEmpty && url == linkText) continue;
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
  /// Fetches with max 3 concurrent connections to reduce battery drain
  Future<List<Article>> fetchAllArticles() async {
    debugPrint('[RSS] Fetching from ${predefinedSources.length} sources...');
    final allArticles = <Article>[];
    const batchSize = 3;

    // Process in batches of 3 to limit concurrent connections
    for (var i = 0; i < predefinedSources.length; i += batchSize) {
      final batch = predefinedSources.skip(i).take(batchSize).toList();
      final results = await Future.wait(
        batch.map((source) => fetchArticles(source)),
        eagerError: false,
      );
      for (final sourceArticles in results) {
        allArticles.addAll(sourceArticles);
      }
      debugPrint('[RSS] Batch ${(i ~/ batchSize) + 1} done, running: ${allArticles.length} total');
    }

    debugPrint('[RSS] Total articles fetched: ${allArticles.length}');

    // Sort by publication date (newest first)
    allArticles.sort((a, b) => b.pubDate.compareTo(a.pubDate));

    return allArticles;
  }

  /// Get source by ID
  RssSource? getSourceById(String id) {
    return sourcesById[id];
  }

  /// Get source color from article - checks embedded metadata first, falls back to source lookup
  Color getSourceColorFromArticle(Article article) {
    if (article.sourceColor != null) {
      try {
        return Color(int.parse(article.sourceColor!.replaceFirst('#', '0xFF')));
      } catch (e) {
        // Fall through to fallback
      }
    }
    final source = getSourceById(article.sourceId);
    return source?.color ?? AppColors.primary;
  }

  /// Get source icon from article - checks embedded metadata first, falls back to source lookup
  IconData getSourceIconFromArticle(Article article) {
    if (article.sourceIcon != null) {
      return _iconNameToData(article.sourceIcon!) ?? Icons.article;
    }
    final source = getSourceById(article.sourceId);
    return source?.icon ?? Icons.article;
  }

  /// Get source name from article - returns embedded name or falls back to source lookup
  String getSourceNameFromArticle(Article article) {
    if (article.sourceName.isNotEmpty) {
      return article.sourceName;
    }
    final source = getSourceById(article.sourceId);
    return source?.name ?? 'Unknown';
  }

  /// Get source category from article - checks embedded metadata first, falls back to source lookup
  String? getSourceCategoryFromArticle(Article article) {
    if (article.sourceCategory != null) {
      return article.sourceCategory;
    }
    final source = getSourceById(article.sourceId);
    return source?.category;
  }

  /// Convert icon string name to IconData
  static IconData? _iconNameToData(String iconName) {
    const iconMap = {
      'rocket_launch': Icons.rocket_launch,
      'devices': Icons.devices,
      'memory': Icons.memory,
      'computer': Icons.computer,
      'devices_other': Icons.devices_other,
      'public': Icons.public,
      'newspaper': Icons.newspaper,
      'biotech': Icons.biotech,
      'rocket': Icons.rocket,
      'sports_soccer': Icons.sports_soccer,
      'theaters_rounded': Icons.theaters_rounded,
      'sports_esports': Icons.sports_esports,
    };
    return iconMap[iconName];
  }
}