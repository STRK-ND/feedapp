import '../models/rss_source.dart';
import '../services/rss_feed_service.dart';
import '../utils/error_handler.dart';
import '../di/service_locator.dart';

/// Repository for RSS feed management
/// Uses dependency injection for testability
class FeedRepository {
  final RssFeedService _rssFeedService;

  FeedRepository({RssFeedService? rssFeedService})
      : _rssFeedService = rssFeedService ?? getIt<RssFeedService>();

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
      final source = _rssFeedService.getSourceById(sourceId);

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

      final allCategories = <String>['All', ...categories];

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
}
