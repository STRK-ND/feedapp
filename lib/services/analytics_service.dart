import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics service for tracking user events in the app
class AnalyticsService {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  // App lifecycle events
  static Future<void> logAppOpen() async {
    await analytics.logAppOpen();
  }

  static Future<void> logAppStart() async {
    await analytics.logEvent(
      name: 'app_start',
      parameters: {},
    );
  }

  // Feed events
  static Future<void> logFeedRefresh() async {
    await analytics.logEvent(
      name: 'feed_refresh',
      parameters: {},
    );
  }

  static Future<void> logFeedLoad({required int articleCount}) async {
    await analytics.logEvent(
      name: 'feed_load',
      parameters: {'article_count': articleCount},
    );
  }

  static Future<void> logFilterChange({required String filter}) async {
    await analytics.logEvent(
      name: 'filter_change',
      parameters: {'filter': filter},
    );
  }

  // Article events
  static Future<void> logArticleOpen({required String articleId, required String title}) async {
    await analytics.logEvent(
      name: 'article_open',
      parameters: {
        'article_id': articleId,
        'title': title,
      },
    );
  }

  static Future<void> logArticleShare({required String articleId}) async {
    await analytics.logEvent(
      name: 'article_share',
      parameters: {'article_id': articleId},
    );
  }

  static Future<void> logArticleLinkOpen({required String articleId}) async {
    await analytics.logEvent(
      name: 'article_link_open',
      parameters: {'article_id': articleId},
    );
  }

  static Future<void> logArticleSave({required String articleId}) async {
    await analytics.logEvent(
      name: 'article_save',
      parameters: {'article_id': articleId},
    );
  }

  static Future<void> logArticleReadComplete({required String articleId}) async {
    await analytics.logEvent(
      name: 'article_read_complete',
      parameters: {'article_id': articleId},
    );
  }

  // Search events
  static Future<void> logSearch({required String query}) async {
    await analytics.logEvent(
      name: 'search',
      parameters: {'query': query},
    );
  }

  // User engagement
  static Future<void> logSessionStart() async {
    await analytics.logEvent(
      name: 'session_start',
      parameters: {},
    );
  }

  static Future<void> logSessionEnd({required int durationSeconds}) async {
    await analytics.logEvent(
      name: 'session_end',
      parameters: {'duration_seconds': durationSeconds},
    );
  }

  // Error tracking
  static Future<void> logError({required String error, String? stackTrace}) async {
    await analytics.logEvent(
      name: 'error',
      parameters: {
        'error': error,
        'stack_trace': ?stackTrace,
      },
    );
  }
}