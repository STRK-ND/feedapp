import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/article.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

/// Worker Feed Service for fetching articles from Cloudflare Worker API
class WorkerFeedService {
  WorkerFeedService._();

  /// Fetch articles from the Worker API
  static Future<List<Article>> fetchArticles() async {
    debugPrint('[Worker] Fetching articles from ${AppConfig.workerApiUrl}');

    try {
      final response = await http
          .get(Uri.parse(AppConfig.workerApiUrl))
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
        final List<dynamic> jsonList = json.decode(response.body);
        final articles = jsonList.map((json) => _parseArticle(json)).toList();
        debugPrint('[Worker] Fetched ${articles.length} articles');
        return articles;
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

  /// Parse a single article from Worker JSON response
  static Article _parseArticle(Map<String, dynamic> json) {
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
  static DateTime _parseDate(dynamic dateValue) {
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
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.workerApiUrl}health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[Worker] Connection test failed: $e');
      return false;
    }
  }
}