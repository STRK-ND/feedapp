import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
    final queryParams = filterParams.toQueryParams();
    // workerApiUrl is the worker base (e.g. ...workers.dev/). Append the
    // articles path so both this and the subscribe concat resolve to real
    // routes — before, replace() stayed on "/" and the worker 404'd.
    final uri = Uri.parse(AppConfig.workerApiUrl)
        .resolve('articles')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final url = uri.toString();

    debugPrint('[Worker] Fetching articles from $url');

    // Retry with exponential backoff for rate limit (429)
    const maxRetries = 3;
    const baseDelayMs = 1000; // Start with 1 second
    final parsedUri = Uri.parse(url);

    // Send the shared API secret when one was compiled in via
    // --dart-define=WORKER_API_SECRET.
    final headers = <String, String>{};
    if (AppConfig.workerApiSecret.isNotEmpty) {
      headers['x-api-secret'] = AppConfig.workerApiSecret;
    }

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await _httpClient
            .get(parsedUri, headers: headers)
            .timeout(
              const Duration(seconds: AppConfig.workerTimeoutSeconds),
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
            final delayMs =
                baseDelayMs * (1 << attempt); // exponential: 1s, 2s, 4s
            debugPrint(
              '[Worker] Rate limited (429), retry ${attempt + 1}/$maxRetries in ${delayMs}ms',
            );
            unawaited(
              ErrorHandler.logError(
                'Worker API rate limited, retrying in ${delayMs}ms',
                severity: ErrorSeverity.medium,
              ),
            );
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
          unawaited(
            ErrorHandler.logError(
              'Worker API rate limited after $maxRetries retries',
              severity: ErrorSeverity.high,
            ),
          );
          throw RateLimitError(
            message: 'Rate limit exceeded. Please try again later.',
          );
        } else {
          unawaited(
            ErrorHandler.logError(
              'Worker API returned ${response.statusCode}',
              severity: ErrorSeverity.high,
            ),
          );
          throw Exception('HTTP ${response.statusCode}');
        }
      } on FormatException catch (e) {
        unawaited(
          ErrorHandler.logError(
            'Invalid JSON response from Worker',
            error: e,
            severity: ErrorSeverity.high,
          ),
        );
        throw Exception('Invalid JSON response');
      } catch (e) {
        if (e is RateLimitError) rethrow;
        // Network error — retry if we have attempts left
        if (attempt < maxRetries - 1) {
          final delayMs = baseDelayMs * (1 << attempt);
          debugPrint(
            '[Worker] Network error: $e, retry ${attempt + 1}/$maxRetries in ${delayMs}ms',
          );
          await Future.delayed(Duration(milliseconds: delayMs));
          continue;
        }
        unawaited(
          ErrorHandler.logError(
            'Failed to fetch from Worker API',
            error: e,
            severity: ErrorSeverity.high,
          ),
        );
        rethrow;
      }
    }

    // Should not reach here, but compiler doesn't know
    throw Exception('Max retries exceeded');
  }
}
