import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/article.dart';
import '../models/paginated_response.dart';
import '../models/filter_params.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

/// Rate limit error from Worker API
class RateLimitError implements Exception {
  final String message;
  final Duration? retryAfter;

  RateLimitError({this.message = 'Rate limit exceeded', this.retryAfter});

  @override
  String toString() => 'RateLimitError: $message';
}

/// Worker Feed Service for fetching articles from Cloudflare Worker API
/// Now uses dependency injection for better testability
class WorkerFeedService {
  final http.Client _httpClient;

  WorkerFeedService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// Fetch articles with pagination and filtering
  /// Includes retry with exponential backoff for rate limit (429) responses
  Future<PaginatedResponse> fetchArticles({FilterParams? params}) async {
    final filterParams = params ?? const FilterParams.defaults();
    final url = filterParams.buildUrl(AppConfig.workerApiUrl);

    debugPrint('[Worker] Fetching articles from $url');

    // Retry with exponential backoff for rate limit (429)
    const maxRetries = 3;
    const baseDelayMs = 1000; // Start with 1 second

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
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
          debugPrint(
            '[Worker] Fetched ${paginatedResponse.items.length} articles (total: ${paginatedResponse.total})',
          );
          return paginatedResponse;
        } else if (response.statusCode == 429) {
          // Rate limited — retry with backoff if we have retries left
          if (attempt < maxRetries) {
            final delayMs = baseDelayMs * (1 << attempt); // exponential: 1s, 2s, 4s
            debugPrint('[Worker] Rate limited (429), retry ${attempt + 1}/$maxRetries in ${delayMs}ms');
            ErrorHandler.logError(
              'Worker API rate limited, retrying in ${delayMs}ms',
              severity: ErrorSeverity.medium,
            );
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
          ErrorHandler.logError(
            'Worker API rate limited after $maxRetries retries',
            severity: ErrorSeverity.high,
          );
          throw RateLimitError(message: 'Rate limit exceeded. Please try again later.');
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
        if (e is RateLimitError) rethrow;
        // Network error — retry if we have attempts left
        if (attempt < maxRetries - 1) {
          final delayMs = baseDelayMs * (1 << attempt);
          debugPrint('[Worker] Network error: $e, retry ${attempt + 1}/$maxRetries in ${delayMs}ms');
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        ErrorHandler.logError(
          'Failed to fetch from Worker API',
          error: e,
          severity: ErrorSeverity.high,
        );
        rethrow;
      }
    }

    // Should not reach here, but compiler doesn't know
    throw Exception('Max retries exceeded');
  }

  /// Fetch all articles as a list (backwards compatible)
  Future<List<Article>> fetchArticlesList() async {
    final response = await fetchArticles();
    return response.items;
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
        debugPrint(
          '[Worker] Fetched full content (${json['wordCount']} words)',
        );
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
