import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import '../utils/constants.dart';
import '../utils/error_handler.dart';

/// Article content with extracted images
class ArticleContent {
  final String text;
  final List<String> images;
  
  ArticleContent({required this.text, required this.images});
}

/// Service to fetch and extract full article content from URLs
/// Now uses dependency injection for better testability
class ArticleContentService {
  final http.Client _httpClient;

  ArticleContentService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Map of domain-specific CSS selectors for article content
  final Map<String, List<String>> _domainSelectors = {
    'techcrunch.com': [
      '.article-entry',
      'article .entry-content',
      '.post-content',
      'article p',
    ],
    'theverge.com': [
      '.c-entry-content',
      'article .duvet--article-body',
      '.article-body',
      '[data-component="ArticleBody"] p',
    ],
    'bbc.com': [
      '.ssrcss-11r1m41-RichTextComponent',
      'article p',
      '.story-body p',
    ],
    'variety.com': [
      '.article-content',
      'article p',
      '.story-body p',
    ],
  };

  /// Fetch full article content from URL with images
  Future<ArticleContent> fetchArticleContentWithImages(String url) async {
    debugPrint('[ArticleContent] Fetching content from: $url');

    try {
      final response = await _httpClient
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
              'Accept': 'text/html,application/xhtml+xml',
            },
          )
          .timeout(
            Duration(seconds: AppConfig.rssTimeoutSeconds),
          );

      if (response.statusCode != 200) {
        debugPrint('[ArticleContent] HTTP ${response.statusCode} for $url');
        throw Exception('HTTP ${response.statusCode}');
      }

      final htmlContent = response.body;
      final document = parser.parse(htmlContent);

      // Extract images first
      final images = _extractImages(document, url);
      debugPrint('[ArticleContent] Found ${images.length} images');

      // Try domain-specific selectors first
      final uri = Uri.parse(url);
      final domain = uri.host.replaceFirst('www.', '');

      for (final domainPattern in _domainSelectors.keys) {
        if (domain.contains(domainPattern)) {
          final selectors = _domainSelectors[domainPattern]!;
          for (final selector in selectors) {
            final content = _extractContentBySelector(document, selector);
            if (content.isNotEmpty) {
              debugPrint('[ArticleContent] Found content using selector: $selector');
              return ArticleContent(text: content, images: images);
            }
          }
        }
      }

      // Fallback: Try generic selectors
      final genericSelectors = [
        'article',
        '[role="article"]',
        'article p',
        '.article-content',
        '.post-content',
        '.entry-content',
        '.content p',
        'main p',
        'article .post-body',
        '.post-body',
      ];

      for (final selector in genericSelectors) {
        final content = _extractContentBySelector(document, selector);
        if (content.isNotEmpty) {
          debugPrint('[ArticleContent] Found content using generic selector: $selector');
          return ArticleContent(text: content, images: images);
        }
      }

      // Last resort: Extract all paragraphs
      final paragraphs = document.querySelectorAll('p');
      final content = paragraphs
          .map((p) => p.text.trim())
          .where((text) => text.isNotEmpty && text.length > 20)
          .take(30)
          .join('\n\n');

      if (content.isNotEmpty) {
        debugPrint('[ArticleContent] Found content using paragraph extraction');
        return ArticleContent(text: content, images: images);
      }

      debugPrint('[ArticleContent] No content found');
      return ArticleContent(
        text: 'Unable to extract article content. Please open in browser to read full article.',
        images: images,
      );
    } catch (e) {
      debugPrint('[ArticleContent] Error fetching content: $e');
      ErrorHandler.logError('Error fetching article content', error: e);
      return ArticleContent(
        text: 'Failed to load article content. Please tap "Open in browser" to read the full article.',
        images: [],
      );
    }
  }

  /// Fetch full article content (backward compatible)
  Future<String> fetchArticleContent(String url) async {
    final result = await fetchArticleContentWithImages(url);
    return result.text;
  }

  /// Extract images from the document
  List<String> _extractImages(dom.Document document, String baseUrl) {
    final images = <String>[];
    final uri = Uri.parse(baseUrl);

    // Try different image selectors
    final selectors = [
      'article img',
      '.article-content img',
      '.post-content img',
      'main img',
      '[role="article"] img',
      '.entry-content img',
      '.article-body img',
      'img.wp-post-image',
      'img.attachment-post-thumbnail',
    ];

    for (final selector in selectors) {
      final elements = document.querySelectorAll(selector);
      for (final img in elements) {
        // Try different attributes
        String? src = img.attributes['src'] ?? 
                      img.attributes['data-src'] ?? 
                      img.attributes['data-lazy-src'] ??
                      img.attributes['data-original'];
        
        if (src != null && src.isNotEmpty) {
          // Skip base64 images, tracking pixels, icons
          if (src.startsWith('data:') || 
              src.contains('pixel') || 
              src.contains('icon') ||
              src.contains('logo') && !src.contains('article')) {
            continue;
          }

          // Handle relative URLs
          if (src.startsWith('//')) {
            src = '${uri.scheme}:$src';
          } else if (src.startsWith('/')) {
            src = '${uri.scheme}://${uri.host}$src';
          }

          // Skip duplicates
          if (!images.contains(src)) {
            images.add(src);
          }
        }
      }
    }

    // Also check for Open Graph and Twitter images
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      final content = ogImage.attributes['content'];
      if (content != null && content.isNotEmpty && !images.contains(content)) {
        images.insert(0, content); // Prioritize OG image
      }
    }

    return images;
  }

  /// Extract content using a CSS selector
  String _extractContentBySelector(dom.Document document, String selector) {
    final elements = document.querySelectorAll(selector);

    if (elements.isEmpty) return '';

    final textBuilder = StringBuilder();

    for (final element in elements) {
      // Skip if this is a container element with nested elements
      if (element.children.isNotEmpty) {
        // Extract text from child elements recursively
        final text = _extractTextFromElement(element);
        if (text.isNotEmpty && text.length > 50) {
          textBuilder.add(text);
          textBuilder.add('\n\n');
        }
      } else {
        // Direct text content
        final text = element.text.trim();
        if (text.isNotEmpty && text.length > 50) {
          textBuilder.add(text);
          textBuilder.add('\n\n');
        }
      }
    }

    return textBuilder.toString().trim();
  }

  /// Extract clean text from an element, removing unwanted content
  String _extractTextFromElement(dom.Element element) {
    final textBuilder = StringBuilder();
    bool hasContent = false;

    // Get all text nodes and paragraph elements
    for (final node in element.nodes) {
      if (node.nodeType == dom.Node.TEXT_NODE) {
        final text = node.text?.trim() ?? '';
        if (text.isNotEmpty) {
          textBuilder.add(text);
          textBuilder.add(' ');
          hasContent = true;
        }
      } else if (node is dom.Element) {
        final tagName = node.localName?.toLowerCase();

        // Skip these elements
        if (tagName != null && [
          'script', 'style', 'nav', 'header', 'footer', 
          'aside', 'iframe', 'video', 'audio', 'figure'
        ].contains(tagName)) {
          continue;
        }

        // Add paragraph breaks
        if (tagName == 'p' || tagName == 'div' || 
            (tagName != null && tagName.startsWith('h'))) {
          if (hasContent) {
            textBuilder.add('\n\n');
          }
        }

        // Recursively process child elements
        final childText = _extractTextFromElement(node);
        if (childText.isNotEmpty) {
          textBuilder.add(childText);
          hasContent = true;
        }
      }
    }

    return cleanText(textBuilder.toString());
  }

  /// Clean extracted text - enhanced to strip HTML, URLs, and RSS artifacts
  String cleanText(String text) {
    if (text.isEmpty) return text;

    // Strip HTML tags using regex
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove bare URLs (http/https/www patterns)
    text = text.replaceAll(RegExp(r'https?://\S+'), '');
    text = text.replaceAll(RegExp(r'www\.\S+'), '');

    // Remove common RSS artifacts like [+], [More], [Read More]
    text = text.replaceAll(RegExp(r'\[(?:\+ ?|More|Read More)\]'), '');
    text = text.replaceAll(RegExp(r'\[\+\]'), '');
    text = text.replaceAll(RegExp(r'\[MORE\]', caseSensitive: false), '');

    // Decode HTML entities (both named and numeric)
    text = _decodeHtmlEntities(text);

    // Remove extra whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Remove common unwanted phrases
    const unwantedPhrases = [
      'Share on Facebook',
      'Share on Twitter',
      'Share via Email',
      'Read more',
      'Continue reading',
      'Advertisement',
      'Ad: ',
      'Sponsored',
      'Subscribe to',
      'Follow us on',
    ];

    for (final phrase in unwantedPhrases) {
      text = text.replaceAll(RegExp(phrase, caseSensitive: false), '');
    }

    return text.trim();
  }

  /// Decode HTML entities (both named entities and numeric character references)
  String _decodeHtmlEntities(String text) {
    // First decode numeric entities (&#8221;, &#8217;, etc.)
    text = text.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '');
        if (code != null) {
          return String.fromCharCode(code);
        }
        return match.group(0) ?? '';
      },
    );

    // Decode hex numeric entities (&#x2019;, etc.)
    text = text.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '', radix: 16);
        if (code != null) {
          return String.fromCharCode(code);
        }
        return match.group(0) ?? '';
      },
    );

    // Then decode named entities
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&copy;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&lsquo;', ''')
        .replaceAll('&rsquo;', ''')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&bull;', '•')
        .replaceAll('&middot;', '·')
        .replaceAll('&deg;', '°');
  }
}

/// Simple string builder for efficient concatenation
class StringBuilder {
  final List<String> _parts = [];

  void add(String part) {
    _parts.add(part);
  }

  @override
  String toString() {
    return _parts.join('');
  }
}