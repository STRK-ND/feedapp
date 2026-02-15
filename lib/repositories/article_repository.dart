import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../utils/error_handler.dart';

/// Repository for managing article data access
class ArticleRepository {
  const ArticleRepository();

  /// Fetch all articles from all sources
  Result<List<Article>> fetchAllArticles() {
    try {
      ErrorHandlerExtensions.logInfo('Fetching all articles');
      // Implementation would call service layer
      final articles = <Article>[];
      return Result.success(articles);
    } catch (e) {
      ErrorHandlerExtensions.logWarning('Failed to fetch all articles: $e');
      return Result.failure(e.toString());
    }
  }

  /// Fetch articles from a specific source
  Result<List<Article>> fetchArticlesFromSource(String sourceId) {
    try {
      ErrorHandlerExtensions.logInfo('Fetching articles from source: $sourceId');
      // Implementation would call service layer
      final articles = <Article>[];
      return Result.success(articles);
    } catch (e) {
      ErrorHandlerExtensions.logWarning(
        'Failed to fetch articles from source $sourceId: $e',
      );
      return Result.failure(e.toString());
    }
  }

  /// Search articles by query
  Result<List<Article>> searchArticles(String query) {
    try {
      ErrorHandlerExtensions.logInfo('Searching articles with query: $query');
      // Implementation would filter articles by query
      final articles = <Article>[];
      return Result.success(articles);
    } catch (e) {
      ErrorHandlerExtensions.logWarning('Failed to search articles: $e');
      return Result.failure(e.toString());
    }
  }

  /// Filter articles by category
  Result<List<Article>> filterByCategory(String category) {
    try {
      ErrorHandlerExtensions.logInfo('Filtering articles by category: $category');
      // Implementation would filter articles by category
      final articles = <Article>[];
      return Result.success(articles);
    } catch (e) {
      ErrorHandlerExtensions.logWarning('Failed to filter articles by category: $e');
      return Result.failure(e.toString());
    }
  }

  /// Filter unread articles
  Result<List<Article>> filterUnread() {
    try {
      ErrorHandlerExtensions.logInfo('Filtering unread articles');
      // Implementation would filter unread articles
      final articles = <Article>[];
      return Result.success(articles);
    } catch (e) {
      ErrorHandlerExtensions.logWarning('Failed to filter unread articles: $e');
      return Result.failure(e.toString());
    }
  }
}

/// Extension on ErrorHandler for logging shortcuts
extension ErrorHandlerExtensions on ErrorHandler {
  /// Log info message
  static void logInfo(String message) {
    ErrorHandler.logError(
      message,
      severity: ErrorSeverity.low,
    );
  }

  /// Log warning message
  static void logWarning(String message) {
    ErrorHandler.logError(
      message,
      severity: ErrorSeverity.medium,
    );
  }
}
