import '../models/rss_source.dart';
import '../services/rss_feed_service.dart';
import '../utils/error_handler.dart';

/// Repository for RSS feed management
class FeedRepository {
  const FeedRepository();

  /// Get all predefined RSS sources
  Future<Result<List<RssSource>>> getAllSources() async {
    try {
      final sources = RssFeedService.predefinedSources;
      ErrorHandler.logError(
        'Retrieved ${sources.length} predefined sources',
        severity: ErrorSeverity.low,
      );
      return Result.success(sources);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get RSS sources',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get source by ID
  Future<Result<RssSource?>> getSourceById(String sourceId) async {
    try {
      final source = RssFeedService.getSourceById(sourceId);

      if (source == null) {
        ErrorHandler.logError(
          'Source not found: $sourceId',
          severity: ErrorSeverity.low,
        );
        return Result.success(null);
      }

      return Result.success(source);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get source by id',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get sources by category
  Future<Result<List<RssSource>>> getSourcesByCategory(String category) async {
    try {
      if (category.isEmpty || category == 'All') {
        final sources = RssFeedService.predefinedSources;
        return Result.success(sources);
      }

      final sources = RssFeedService.predefinedSources
          .where((source) => source.category == category)
          .toList();

      return Result.success(sources);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get sources by category',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get all available categories
  Future<Result<List<String>>> getCategories() async {
    try {
      final categories = RssFeedService.predefinedSources
          .map((source) => source.category)
          .toSet()
          .toList()
        ..sort();

      final allCategories = ['All', ...categories];

      ErrorHandler.logError(
        'Retrieved ${allCategories.length} categories',
        severity: ErrorSeverity.low,
      );
      return Result.success(allCategories);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get categories',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get feed health status (placeholder for future enhancement)
  Future<Result<Map<String, bool>>> getFeedHealth() async {
    try {
      // In future: actually ping each feed to check health
      // For now, return all as healthy
      final health = {
        for (var source in RssFeedService.predefinedSources)
          source.id: true
      };

      return Result.success(health);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get feed health',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
}
