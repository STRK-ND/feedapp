import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../utils/helpers.dart';

/// Service to fetch and extract full article content from URLs
class ArticleContentService {
  ArticleContentService._();

  /// Map of domain-specific CSS selectors for article content
  static const Map<String, List<String>> _domainSelectors = {
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
    'cnn.com': [
      '.l-container p',
      '.zn-body__paragraph',
      'article .pg-rail-tall__body p',
    ],
  };

  /// Fetch full article content from URL
  static Future<String> fetchArticleContent(String url) async {
    debugPrint('[ArticleContent] Fetching content from: $url');

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: AppConfig.rssTimeoutSeconds),
          );

      if (response.statusCode != 200) {
        debugPrint('[ArticleContent] HTTP ${response.statusCode} for $url');
        throw Exception('HTTP ${response.statusCode}');
      }

      final htmlContent = response.body;
      final document = parser.parse(htmlContent);

      // Try domain-specific selectors first
      final uri = Uri.parse(url);
      final domain = uri.host.replaceFirst('www.', '');

      for (var domainPattern in _domainSelectors.keys) {
        if (domain.contains(domainPattern)) {
          final selectors = _domainSelectors[domainPattern]!;
          for (var selector in selectors) {
            final content = _extractContentBySelector(document, selector);
            if (content.isNotEmpty) {
              debugPrint('[ArticleContent] Found content using selector: $selector');
              return content;
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

      for (var selector in genericSelectors) {
        final content = _extractContentBySelector(document, selector);
        if (content.isNotEmpty) {
          debugPrint('[ArticleContent] Found content using generic selector: $selector');
          return content;
        }
      }

      // Last resort: Extract all paragraphs
      final paragraphs = document.querySelectorAll('p');
      final content = paragraphs
          .map((p) => p.text.trim())
          .where((text) => text.isNotEmpty && text.length > 20)
          .take(30) // Limit to 30 paragraphs
          .join('\n\n');

      if (content.isNotEmpty) {
        debugPrint('[ArticleContent] Found content using paragraph extraction');
        return content;
      }

      debugPrint('[ArticleContent] No content found');
      return 'Unable to extract article content. Please open in browser to read full article.';
    } catch (e) {
      debugPrint('[ArticleContent] Error fetching content: $e');
      ErrorHandler.logError('Error fetching article content', error: e);
      return 'Failed to load article content. Please tap "Open in browser" to read the full article.';
    }
  }

  /// Extract content using a CSS selector
  static String _extractContentBySelector(dom.Document document, String selector) {
    final elements = document.querySelectorAll(selector);

    if (elements.isEmpty) return '';

    final textBuilder = StringBuilder();

    for (var element in elements) {
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
  static String _extractTextFromElement(dom.Element element) {
    final textBuilder = StringBuilder();
    bool hasContent = false;

    // Get all text nodes and paragraph elements
    for (var node in element.nodes) {
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
        if (['script', 'style', 'nav', 'header', 'footer', 'aside',
              'iframe', 'video', 'audio', 'figure', 'img'].contains(tagName)) {
          continue;
        }

        // Add paragraph breaks
        if (tagName == 'p' || tagName == 'div' || tagName == 'h1' ||
            tagName == 'h2' || tagName == 'h3' || tagName == 'h4' ||
            tagName == 'h5' || tagName == 'h6') {
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

  /// Clean extracted text
  static String cleanText(String text) {
    // Remove extra whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Remove common unwanted phrases
    final unwantedPhrases = [
      r'Share on Facebook',
      r'Share on Twitter',
      r'Share via Email',
      r'Read more',
      r'Continue reading',
      r'Advertisement',
      r'Ad: ',
      r'Sponsored',
      r'Subscribe to',
      r'Follow us on',
    ];

    for (var phrase in unwantedPhrases) {
      text = text.replaceAll(RegExp(phrase, caseSensitive: false), '');
    }

    return text.trim();
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
