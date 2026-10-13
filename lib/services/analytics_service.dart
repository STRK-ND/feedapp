import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'posthog_service.dart';

/// Analytics service for tracking user events in the app.
/// Every event fans out to Firebase Analytics and PostHog; the PostHog
/// leg is a no-op until POSTHOG_API_KEY is configured (see
/// docs/monitoring-setup.md).
class AnalyticsService {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  /// Single fan-out point for all named events. Both legs are guarded:
  /// analytics is fire-and-forget telemetry and must never crash UI code
  /// — e.g. a screen opened before Firebase.initializeApp (tests, or a
  /// paywall reachable in odd startup orders) would otherwise throw
  /// [core/no-app] out of initState.
  static Future<void> _log(String name, Map<String, Object>? params) async {
    unawaited(PostHogService.capture(name, params));
    try {
      await analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      // Swallowed by design: telemetry failure is never a user-facing
      // error. Crashlytics/Sentry still see real crashes elsewhere.
    }
  }

  // App lifecycle events
  static Future<void> logAppOpen() async {
    unawaited(PostHogService.capture('app_open'));
    try {
      await analytics.logAppOpen();
    } catch (_) {
      // Same guard as _log — see there.
    }
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

  // =========================================================================
  // Monetisation funnel (R-3). Without these the paywall cannot be
  // measured: no view, no attempt, no completion, no cap-hit. `trigger`
  // ('save_cap_swipe' | 'save_cap_button' | 'theme_lock' | 'settings') is
  // what makes comparing entry points possible later. Keep article
  // CONTENT out of these params — titles are already a disclosure
  // surface in logArticleOpen; do not widen it here.
  // =========================================================================

  static Future<void> logPaywallShown({
    required String trigger,
    required int savedCount,
  }) => _log('paywall_shown', {'trigger': trigger, 'saved_count': savedCount});

  static Future<void> logPaywallAction({
    required String action, // 'buy' | 'restore' | 'dismiss'
    required String trigger,
  }) => _log('paywall_action', {'action': action, 'trigger': trigger});

  static Future<void> logPurchaseCompleted({required String productId}) =>
      _log('purchase_completed', {'product_id': productId});

  static Future<void> logCapHit({required int savedCount}) =>
      _log('cap_hit', {'saved_count': savedCount});

  // =========================================================================
  // In-app review prompt (R-4).
  // =========================================================================

  /// Store's own timestamp key so the 90-day discipline survives the
  /// analytics service being refactored.
  static const String _kLastReviewAskMs = 'last_review_ask_ms';
  static const Duration _reviewAskInterval = Duration(days: 90);

  /// Requests a store review at most once per 90 days (Google's guidance
  /// is "a few times a year"; InAppReview enforces no limit itself). The
  /// prompt is suppressed by Google on emulators and in some regions —
  /// a no-op there, by design. Call only at a genuine satisfaction
  /// signal, never on launch, never on a timer, never to Pro users who
  /// have already paid (see the caller in expanded_article_card).
  static Future<void> maybeRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kLastReviewAskMs) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _reviewAskInterval.inMilliseconds) return;

      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      await prefs.setInt(_kLastReviewAskMs, now);
      await review.requestReview();
    } catch (_) {
      // A failed review prompt must never surface as an error to the
      // user; the next 90-day window will try again.
    }
  }
}
