import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/article.dart';
import '../models/rss_source.dart';
import '../utils/constants.dart';

/// Bundled source list. Used only before the first successful /sources
/// fetch and when neither the cached list nor the network is available —
/// the worker's GET /sources list is the source of truth.
const List<RssSource> _kOfflineSeedSources = [
  RssSource(
    id: 'verge',
    name: 'The Verge',
    url: 'https://www.theverge.com/rss/index.xml',
    category: 'Tech',
    color: AppColors.techSecondary,
    icon: Icons.devices,
  ),
  RssSource(
    id: 'wired',
    name: 'Wired',
    url: 'https://www.wired.com/feed/rss',
    category: 'Tech',
    color: AppColors.techSecondary,
    icon: Icons.memory,
  ),
  RssSource(
    id: 'bbc',
    name: 'BBC World',
    url: 'https://feeds.bbci.co.uk/news/rss.xml',
    category: 'News',
    color: AppColors.newsPrimary,
    icon: Icons.public,
  ),
  RssSource(
    id: 'newscientist',
    name: 'New Scientist',
    url: 'https://www.newscientist.com/feed/home/',
    category: 'Science',
    color: AppColors.scienceSecondary,
    icon: Icons.biotech,
  ),
  RssSource(
    id: 'skysports',
    name: 'Sky Sports',
    url: 'https://www.skysports.com/rss/12040',
    category: 'Sports',
    color: AppColors.sportsSecondary,
    icon: Icons.sports_soccer,
  ),
  RssSource(
    id: 'variety',
    name: 'Variety',
    url: 'https://variety.com/feed/',
    category: 'Entertainment',
    color: AppColors.entertainmentPrimary,
    icon: Icons.theaters_rounded,
  ),
  RssSource(
    id: 'arstechnica',
    name: 'Ars Technica',
    url: 'https://feeds.arstechnica.com/arstechnica/index',
    category: 'Tech',
    color: AppColors.techSecondary,
    icon: Icons.computer,
  ),
  RssSource(
    id: 'techcrunch',
    name: 'TechCrunch',
    url: 'https://techcrunch.com/feed/',
    category: 'Tech',
    color: AppColors.techSecondary,
    icon: Icons.rocket_launch,
  ),
  RssSource(
    id: 'engadget',
    name: 'Engadget',
    url: 'https://www.engadget.com/rss.xml',
    category: 'Tech',
    color: AppColors.techSecondary,
    icon: Icons.devices_other,
  ),
  RssSource(
    id: 'guardian',
    name: 'The Guardian',
    url: 'https://www.theguardian.com/world/rss',
    category: 'News',
    color: AppColors.newsPrimary,
    icon: Icons.newspaper,
  ),
  RssSource(
    id: 'ign',
    name: 'IGN',
    url: 'https://feeds.ign.com/ign/games-all',
    category: 'Gaming',
    color: AppColors.gamingSecondary,
    icon: Icons.sports_esports,
  ),
  RssSource(
    id: 'nasa',
    name: 'NASA',
    url: 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
    category: 'Science',
    color: AppColors.scienceSecondary,
    icon: Icons.rocket,
  ),
];

/// IDs of the current canonical source registry (worker list, cached
/// locally, bundled seed before the first fetch). Settings persistence
/// validates stored subscription ids against this set so the list can't
/// drift apart from what sources/feed screens render.
Set<String> canonicalSourceIds() {
  final getIt = GetIt.instance;
  final sources = getIt.isRegistered<RssFeedService>()
      ? getIt<RssFeedService>().sources
      : _kOfflineSeedSources;
  return sources.map((s) => s.id).toSet();
}

/// Source registry: loads the last fetched canonical list from prefs,
/// refreshes it from the worker's GET /sources, and resolves source
/// metadata (color, name) for articles.
class RssFeedService {
  RssFeedService({http.Client? httpClient, Future<SharedPreferences>? prefs})
    : _httpClient = httpClient ?? http.Client(),
      _prefsFuture = prefs;

  static const String _cacheKey = 'source_registry_v1';

  /// Worker icon name → Material icon mapping lives in
  /// `rss_source.dart` (`kSourceIcons`) so the model's cache round-trip
  /// resolves against the same const icon set.

  final http.Client _httpClient;
  Future<SharedPreferences>? _prefsFuture;
  Future<void>? _initFuture;

  List<RssSource> _sources = _kOfflineSeedSources;

  /// Current source registry. Never empty: seeded with the bundled list
  /// until the cached/fetched list replaces it.
  List<RssSource> get sources => _sources;

  /// Load the cached registry from prefs. Idempotent.
  Future<void> init() => _initFuture ??= _loadCache();

  Future<void> _loadCache() async {
    try {
      final prefs = await (_prefsFuture ??= SharedPreferences.getInstance());
      final raw = prefs.getStringList(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = raw
          .map((entry) {
            try {
              return RssSource.fromJson(
                jsonDecode(entry) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<RssSource>()
          .where((s) => s.id.isNotEmpty && s.url.isNotEmpty)
          .toList();
      if (decoded.isNotEmpty) _sources = decoded;
    } catch (e) {
      debugPrint('[RssFeedService] Source cache load failed: $e');
    }
  }

  /// Fetch the canonical source list from the worker and cache it.
  /// Returns true when the registry was updated. Failures (offline,
  /// non-200, malformed body) leave the current list untouched.
  Future<bool> refreshFromWorker() async {
    try {
      final uri = Uri.parse(AppConfig.workerApiUrl).resolve('sources');
      final response = await _httpClient
          .get(uri)
          .timeout(const Duration(seconds: AppConfig.workerTimeoutSeconds));
      if (response.statusCode != 200) return false;

      final items =
          (jsonDecode(response.body) as Map<String, dynamic>)['sources'];
      if (items is! List || items.isEmpty) return false;

      final parsed = items
          .whereType<Map<String, dynamic>>()
          .map(_sourceFromWorker)
          .whereType<RssSource>()
          .toList();
      if (parsed.isEmpty) return false;

      _sources = parsed;
      final prefs = await (_prefsFuture ??= SharedPreferences.getInstance());
      await prefs.setStringList(
        _cacheKey,
        parsed.map((s) => jsonEncode(s.toJson())).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('[RssFeedService] Source refresh failed: $e');
      return false;
    }
  }

  RssSource? _sourceFromWorker(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final url = json['url'] as String?;
    if (id == null || id.isEmpty || name == null || url == null) return null;
    final category = json['category'] as String? ?? 'Custom';
    return RssSource(
      id: id,
      name: name,
      url: url,
      category: category,
      color: _colorForName(json['color'] as String?, category),
      icon: kSourceIcons[json['icon'] as String?] ?? RssSource.customIcon,
    );
  }

  static Color _colorForName(String? hex, String category) {
    if (hex != null && hex.length > 1) {
      try {
        return Color(int.parse(hex.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return switch (category) {
      'Tech' => AppColors.techSecondary,
      'News' => AppColors.newsPrimary,
      'Science' => AppColors.scienceSecondary,
      'Sports' => AppColors.sportsSecondary,
      'Entertainment' => AppColors.entertainmentPrimary,
      'Gaming' => AppColors.gamingSecondary,
      _ => RssSource.customColor,
    };
  }

  /// Get source by ID
  RssSource? getSourceById(String id) {
    try {
      return _sources.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get source color from article - checks embedded metadata first, falls back to source lookup
  Color getSourceColorFromArticle(Article article) {
    if (article.sourceColor != null) {
      try {
        return Color(int.parse(article.sourceColor!.replaceFirst('#', '0xFF')));
      } catch (e) {
        // Fall through to fallback
      }
    }
    final source = getSourceById(article.sourceId);
    return source?.color ?? AppColors.primary;
  }

  /// Get source name from article - returns embedded name or falls back to source lookup
  String getSourceNameFromArticle(Article article) {
    if (article.sourceName.isNotEmpty) {
      return article.sourceName;
    }
    final source = getSourceById(article.sourceId);
    return source?.name ?? 'Unknown';
  }
}
