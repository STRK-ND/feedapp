import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'posthog_service.dart';

/// Analytics service for tracking user events in the app.
/// Every event fans out to Firebase Analytics and PostHog; the PostHog
/// leg is a no-op until POSTHOG_API_KEY is configured (see
/// docs/monitoring-setup.md).
class AnalyticsService {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  /// Single fan-out point for all named events.
  static Future<void> _log(String name, Map<String, Object>? params) async {
    unawaited(PostHogService.capture(name, params));
    await analytics.logEvent(name: name, parameters: params);
  }

  // App lifecycle events
  static Future<void> logAppOpen() async {
    unawaited(PostHogService.capture('app_open'));
    await analytics.logAppOpen();
  }

  static Future<void> logAppStart() => _log('app_start', {});

  // Feed events
  static Future<void> logFeedRefresh() => _log('feed_refresh', {});

  static Future<void> logFeedLoad({required int articleCount}) =>
      _log('feed_load', {'article_count': articleCount});

  static Future<void> logFilterChange({required String filter}) =>
      _log('filter_change', {'filter': filter});

  // Article events
  static Future<void> logArticleOpen({
    required String articleId,
    required String title,
  }) => _log('article_open', {'article_id': articleId, 'title': title});

  static Future<void> logArticleShare({required String articleId}) =>
      _log('article_share', {'article_id': articleId});

  static Future<void> logArticleLinkOpen({required String articleId}) =>
      _log('article_link_open', {'article_id': articleId});

  static Future<void> logArticleSave({required String articleId}) =>
      _log('article_save', {'article_id': articleId});

  static Future<void> logArticleReadComplete({required String articleId}) =>
      _log('article_read_complete', {'article_id': articleId});

  // Search events
  static Future<void> logSearch({required String query}) =>
      _log('search', {'query': query});

  // User engagement
  static Future<void> logSessionStart() => _log('session_start', {});

  static Future<void> logSessionEnd({required int durationSeconds}) =>
      _log('session_end', {'duration_seconds': durationSeconds});

  // Error tracking
  static Future<void> logError({required String error, String? stackTrace}) =>
      _log('error', {'error': error, 'stack_trace': ?stackTrace});
}
