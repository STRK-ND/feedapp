import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/article.dart';
import '../models/paginated_response.dart';
import '../models/filter_params.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

/// Worker Feed Service for fetching articles from Cloudflare Worker API
/// Now uses dependency injection for better testability
class WorkerFeedService {
  final http.Client _httpClient;

  WorkerFeedService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Fetch articles with pagination and filtering
  Future<PaginatedResponse> fetchArticles({FilterParams? params}) async {
    final filterParams = params ?? const FilterParams.defaults();
    final url = filterParams.buildUrl(AppConfig.workerApiUrl);

    debugPrint('[Worker] Fetching articles from $url');

    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(
            Duration(seconds: AppConfig.workerTimeoutSeconds),
            onTimeout: () {
              ErrorHandler.logError(
                'Worker API timeout after ${AppConfig.workerTimeoutSeconds}s',
                severity: ErrorSeverity.high,
              );
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final paginatedResponse = PaginatedResponse.fromJson(json);
        debugPrint('[Worker] Fetched ${paginatedResponse.items.length} articles (total: ${paginatedResponse.total})');
        return paginatedResponse;
      } else {
        ErrorHandler.logError(
          'Worker API returned ${response.statusCode}',
          severity: ErrorSeverity.high,
        );
        throw Exception('HTTP ${response.statusCode}');
      }
    } on FormatException catch (e) {
      ErrorHandler.logError(
        'Invalid JSON response from Worker',
        error: e,
        severity: ErrorSeverity.high,
      );
      throw Exception('Invalid JSON response');
    } catch (e) {
      ErrorHandler.logError(
        'Failed to fetch from Worker API',
        error: e,
        severity: ErrorSeverity.high,
      );
      rethrow;
    }
  }

  /// Fetch all articles as a list (backwards compatible)
  Future<List<Article>> fetchArticlesList() async {
    final response = await fetchArticles();
    return response.items;
  }

  /// Parse a single article from Worker JSON response
  Article _parseArticle(Map<String, dynamic> json) {
    return Article(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      fullContent: json['fullContent'] as String? ?? '',
      link: json['link'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? 'Unknown Source',
      pubDate: _parseDate(json['pubDate']),
      author: json['author'] as String?,
      imageUrl: json['imageUrl'] as String?,
      sourceCategory: json['sourceCategory'] as String?,
      sourceColor: json['sourceColor'] as String?,
      sourceIcon: json['sourceIcon'] as String?,
    );
  }

  /// Parse date from ISO string or epoch milliseconds
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();

    if (dateValue is int) {
      return DateTime.fromMillisecondsSinceEpoch(dateValue, isUtc: true);
    }

    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    }

    return DateTime.now();
  }

  /// Test the Worker API connection
  Future<bool> testConnection() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('${AppConfig.workerApiUrl}health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Worker] Connection test failed: $e');
      return false;
    }
  }

  /// Fetch available sources from Worker
  Future<List<Map<String, dynamic>>> fetchSources() async {
    final sourcesUrl = '${AppConfig.workerApiUrl}sources';
    debugPrint('[Worker] Fetching sources from $sourcesUrl');

    try {
      final response = await _httpClient
          .get(Uri.parse(sourcesUrl))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Sources request timeout');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final sources = (json['sources'] as List<dynamic>)
            .map((s) => s as Map<String, dynamic>)
            .toList();
        debugPrint('[Worker] Fetched ${sources.length} sources');
        return sources;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(
        'Failed to fetch sources',
        error: e,
        severity: ErrorSeverity.medium,
      );
      rethrow;
    }
  }

  /// Fetch full content for an article
  Future<Map<String, dynamic>?> fetchFullContent(String articleUrl) async {
    final encodedUrl = Uri.encodeComponent(articleUrl);
    final contentUrl = '${AppConfig.workerApiUrl}full-content?url=$encodedUrl';

    debugPrint('[Worker] Fetching full content');

    try {
      final response = await _httpClient
          .get(Uri.parse(contentUrl))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Full content request timeout');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[Worker] Fetched full content (${json['wordCount']} words)');
        return json;
      } else if (response.statusCode == 400) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(json['error'] ?? 'Invalid request');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(
        'Failed to fetch full content',
        error: e,
        severity: ErrorSeverity.medium,
      );
      return null;
    }
  }
}