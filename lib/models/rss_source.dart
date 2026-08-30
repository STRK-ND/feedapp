import 'package:flutter/material.dart';

/// RSS Feed Source Model
class RssSource {
  final String id;
  final String name;
  final String url;
  final String category;
  final Color color;
  final IconData icon;

  const RssSource({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.color,
    required this.icon,
  });

  /// Default look for user-added custom feeds.
  static const Color customColor = Color(0xFF9A97A6);
  static const IconData customIcon = Icons.rss_feed_rounded;

  factory RssSource.custom({
    required String id,
    required String name,
    required String url,
    Color? color,
  }) {
    return RssSource(
      id: id,
      name: name,
      url: url,
      category: 'Custom',
      color: color ?? customColor,
      icon: customIcon,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'category': category,
        'color': '#${color.toARGB32().toRadixString(16).substring(2)}',
        'iconCodePoint': icon.codePoint,
      };

  factory RssSource.fromJson(Map<String, dynamic> json) {
    return RssSource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      url: json['url'] as String? ?? '',
      category: json['category'] as String? ?? 'Custom',
      color: _parseColor(json['color'] as String?),
      icon: IconData(
        (json['iconCodePoint'] as num?)?.toInt() ?? customIcon.codePoint,
        fontFamily: 'MaterialIcons',
      ),
    );
  }

  /// Stable id derived from the feed URL. Dart's String.hashCode is NOT
  /// stable across runs, so a small deterministic hash is used instead —
  /// ids must survive restarts or saved/read flags would orphan.
  static String stableIdForUrl(String url) {
    var h = 0;
    for (final cu in url.codeUnits) {
      h = ((h << 5) - h + cu) & 0x3FFFFFFF;
    }
    return 'custom-${h.toRadixString(36)}';
  }

  static Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return customColor;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return customColor;
    }
  }
}
