import 'package:flutter/material.dart';
import '../models/article.dart';
import '../models/rss_source.dart';
import '../utils/constants.dart';

/// Canonical set of RSS source IDs — shared by settings persistence and
/// the sources screen so they can't drift apart.
Set<String> canonicalSourceIds() =>
    RssFeedService.predefinedSources.map((s) => s.id).toSet();

/// RSS Feed Service for managing predefined RSS source metadata
class RssFeedService {
  /// Predefined RSS sources as a list (for iteration) - filtered to image-friendly sources
  static final List<RssSource> predefinedSources = [
    // Tech
    const RssSource(
      id: 'verge',
      name: 'The Verge',
      url: 'https://www.theverge.com/rss/index.xml',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.devices,
    ),
    const RssSource(
      id: 'wired',
      name: 'Wired',
      url: 'https://www.wired.com/feed/rss',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.memory,
    ),
    // News
    const RssSource(
      id: 'bbc',
      name: 'BBC World',
      url: 'https://feeds.bbci.co.uk/news/rss.xml',
      category: 'News',
      color: AppColors.newsPrimary,
      icon: Icons.public,
    ),
    // Science
    const RssSource(
      id: 'newscientist',
      name: 'New Scientist',
      url: 'https://www.newscientist.com/feed/home/',
      category: 'Science',
      color: AppColors.scienceSecondary,
      icon: Icons.biotech,
    ),
    // Sports - using ESPN as Bleacher Report URL is broken
    const RssSource(
      id: 'skysports',
      name: 'Sky Sports',
      url: 'https://www.skysports.com/rss/12040',
      category: 'Sports',
      color: AppColors.sportsSecondary,
      icon: Icons.sports_soccer,
    ),
    // Entertainment
    const RssSource(
      id: 'variety',
      name: 'Variety',
      url: 'https://variety.com/feed/',
      category: 'Entertainment',
      color: AppColors.entertainmentPrimary,
      icon: Icons.theaters_rounded,
    ),
    // Tech - Additional sources
    const RssSource(
      id: 'arstechnica',
      name: 'Ars Technica',
      url: 'https://feeds.arstechnica.com/arstechnica/index',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.computer,
    ),
    const RssSource(
      id: 'techcrunch',
      name: 'TechCrunch',
      url: 'https://techcrunch.com/feed/',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.rocket_launch,
    ),
    const RssSource(
      id: 'engadget',
      name: 'Engadget',
      url: 'https://www.engadget.com/rss.xml',
      category: 'Tech',
      color: AppColors.techSecondary,
      icon: Icons.devices_other,
    ),
    // News - Additional sources
    const RssSource(
      id: 'guardian',
      name: 'The Guardian',
      url: 'https://www.theguardian.com/world/rss',
      category: 'News',
      color: AppColors.newsPrimary,
      icon: Icons.newspaper,
    ),
    // Gaming
    const RssSource(
      id: 'ign',
      name: 'IGN',
      url: 'https://feeds.ign.com/ign/games-all',
      category: 'Gaming',
      color: AppColors.gamingSecondary,
      icon: Icons.sports_esports,
    ),
    // Science - Additional sources
    const RssSource(
      id: 'nasa',
      name: 'NASA',
      url: 'https://www.nasa.gov/rss/dyn/breaking_news.rss',
      category: 'Science',
      color: AppColors.scienceSecondary,
      icon: Icons.rocket,
    ),
  ];

  /// Get source by ID
  RssSource? getSourceById(String id) {
    try {
      return predefinedSources.firstWhere((s) => s.id == id);
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
