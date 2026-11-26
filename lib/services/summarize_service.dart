/// Pro AI summaries — client side (market roadmap Tier 1, feature 4).
///
/// The worker (`POST /summarize`) verifies a Firebase ID token, keys a
/// monthly budget on the REAL uid, and runs the article text through
/// Workers AI. This service owns the request, the local summary cache
/// (summaries are immutable per body text — a cache hit never re-spends
/// budget), and the free-tier trial counter that gates the UI for
/// non-Pro users.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/article.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

/// Must match the worker's SUMMARIZE_MAX_TEXT_CHARS clamp.
const int kSummaryMaxTextChars = 8000;

/// Minimum body length the worker accepts; shorter articles have nothing
/// to summarize, so the UI hides the action.
const int kSummaryMinBodyChars = 200;

/// Free-tier monthly trial allowance, enforced client-side (the server
/// budget is the abuse backstop, not the tier gate).
const int kFreeTrialMonthlySummaries = 5;

enum SummaryStatus { success, budgetExhausted, rateLimited, authFailed, failed }

class SummaryResult {
  final SummaryStatus status;
  final String? summary;

  const SummaryResult._(this.status, this.summary);

  const SummaryResult.success(String text)
    : this._(SummaryStatus.success, text);
  const SummaryResult.failure(SummaryStatus status) : this._(status, null);
}

class SummarizeService {
  SummarizeService({
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
    SharedPreferences? prefs,
  }) : _httpClient = httpClient ?? http.Client(),
       _idTokenProvider = idTokenProvider ?? defaultIdTokenProvider,
       _prefs = prefs;

  final http.Client _httpClient;
  final Future<String?> Function() _idTokenProvider;

  /// Production token source: the signed-in Firebase user.
  static Future<String?> defaultIdTokenProvider() async {
    return AuthService().getIdToken();
  }

  SharedPreferences? _prefs;

  /// In-session cache: article id → summary. Persisted across sessions
  /// via StorageService's summaries table (see `getSummary` callers).
  final Map<String, String> _memoryCache = {};

  static const String _kFreeUsedKey = 'summary_free_used';
  static const String _kFreeYmKey = 'summary_free_ym';

  Future<SharedPreferences> _prefsInstance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Current UTC month key, mirroring the worker's budget key format.
  @visibleForTesting
  static String currentYm(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  /// How many free-trial summaries the user has left this month.
  Future<int> remainingFreeTrial() async {
    final prefs = await _prefsInstance();
    final now = DateTime.now().toUtc();
    if (prefs.getString(_kFreeYmKey) != currentYm(now)) {
      return kFreeTrialMonthlySummaries;
    }
    final used = prefs.getInt(_kFreeUsedKey) ?? 0;
    return (kFreeTrialMonthlySummaries - used).clamp(
      0,
      kFreeTrialMonthlySummaries,
    );
  }

  /// Record one free-trial use against the current month.
  Future<void> recordFreeUse() async {
    final prefs = await _prefsInstance();
    final now = DateTime.now().toUtc();
    final used = prefs.getString(_kFreeYmKey) == currentYm(now)
        ? (prefs.getInt(_kFreeUsedKey) ?? 0) + 1
        : 1;
    await prefs.setInt(_kFreeUsedKey, used);
    await prefs.setString(_kFreeYmKey, currentYm(now));
  }

  /// The body text to summarize: the extracted/full body when present,
  /// otherwise the description. Null when there is nothing substantial
  /// enough for the worker to accept.
  @visibleForTesting
  static String? summarizableBody(Article article) {
    final body = article.fullContent.isNotEmpty
        ? article.fullContent
        : article.description;
    if (body.trim().length < kSummaryMinBodyChars) return null;
    if (body.length > kSummaryMaxTextChars) {
      return body.substring(0, kSummaryMaxTextChars);
    }
    return body;
  }

  /// Cached summary for [articleId] (memory first, then the persisted
  /// side table via [persistentLookup]).
  String? cachedSummary(String articleId) => _memoryCache[articleId];

  void primeCache(String articleId, String summary) {
    _memoryCache[articleId] = summary;
  }

  /// Request a summary for [article]. [persistentLookup] supplies the
  /// on-disk cache (FeedDatabase.getSummary via StorageService) so a
  /// summary bought with budget once is never bought again.
  Future<SummaryResult> summarize(
    Article article, {
    Future<String?> Function(String articleId)? persistentLookup,
    Future<void> Function(String articleId, String text)? persist,
  }) async {
    final cached =
        _memoryCache[article.id] ?? await persistentLookup?.call(article.id);
    if (cached != null && cached.isNotEmpty) {
      _memoryCache[article.id] = cached;
      return SummaryResult.success(cached);
    }

    final body = summarizableBody(article);
    if (body == null) return const SummaryResult.failure(SummaryStatus.failed);

    final idToken = await _idTokenProvider();
    if (idToken == null || idToken.isEmpty) {
      return const SummaryResult.failure(SummaryStatus.authFailed);
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
    if (AppConfig.workerApiSecret.isNotEmpty) {
      headers['x-api-secret'] = AppConfig.workerApiSecret;
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse(AppConfig.workerApiUrl).resolve('summarize'),
            headers: headers,
            body: jsonEncode({'articleId': article.id, 'text': body}),
          )
          .timeout(const Duration(seconds: 30));

      switch (response.statusCode) {
        case 200:
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final summary = (data['summary'] as String?)?.trim() ?? '';
          if (summary.isEmpty) {
            return const SummaryResult.failure(SummaryStatus.failed);
          }
          _memoryCache[article.id] = summary;
          await persist?.call(article.id, summary);
          return SummaryResult.success(summary);
        case 429:
          final error =
              (jsonDecode(response.body) as Map<String, dynamic>)['error'];
          return SummaryResult.failure(
            error == 'rate_limited'
                ? SummaryStatus.rateLimited
                : SummaryStatus.budgetExhausted,
          );
        case 401:
        case 403:
          return const SummaryResult.failure(SummaryStatus.authFailed);
        default:
          return const SummaryResult.failure(SummaryStatus.failed);
      }
    } catch (e) {
      debugPrint('[SummarizeService] request failed: $e');
      return const SummaryResult.failure(SummaryStatus.failed);
    }
  }
}
