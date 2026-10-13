import 'package:flutter/material.dart';

/// Worker icon name → Material icon, shared by the source registry and
/// the cache round-trip. All values are const so release builds can
/// tree-shake the icon font — dynamic `IconData(...)` construction makes
/// the shaker bail out and fails `flutter build --release` outright.
const Map<String, IconData> kSourceIcons = {
  'devices': Icons.devices,
  'memory': Icons.memory,
  'public': Icons.public,
  'biotech': Icons.biotech,
  'sports_soccer': Icons.sports_soccer,
  'theaters': Icons.theaters_rounded,
  'computer': Icons.computer,
  'rocket_launch': Icons.rocket_launch,
  'devices_other': Icons.devices_other,
  'newspaper': Icons.newspaper,
  'sports_esports': Icons.sports_esports,
  'rocket': Icons.rocket,
};

/// Cached `iconCodePoint` → the same const IconData instance, so a prefs
/// round-trip never constructs IconData dynamically.
final Map<int, IconData> _iconByCodePoint = {
  for (final entry in kSourceIcons.entries) entry.value.codePoint: entry.value,
};

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
      icon:
          _iconByCodePoint[(json['iconCodePoint'] as num?)?.toInt()] ??
          customIcon,
    );
  }

  /// Stable id derived from the feed URL. Dart's String.hashCode is NOT
  /// stable across runs, so a small deterministic hash is used instead —
  /// ids must survive restarts or saved/read flags would orphan.
  ///
  /// I-9: the mask is 53 bits, not 30. The old `& 0x3FFFFFFF` left only
  /// ~1.07e9 values, and because `ClientFeedService._build` derives every
  /// article id as `${source.id}-${hash(link)}`, two sources colliding on
  /// id produced colliding article ids — SQLite `id` is PRIMARY KEY, so one
  /// feed silently overwrote the other's articles. 53 bits needs ~9e15
  /// distinct URLs before a collision is likelier than not (birthday bound
  /// √2^53 ≈ 9.5e7 URLs), which is unreachable for a per-device custom-feed
  /// list, and stays safely inside Dart's 64-bit int for the `<< 5` step.
  /// The hash alone is not a uniqueness proof, so
  /// [SettingsService.addCustomSource] also provably disambiguates at insert.
  static String stableIdForUrl(String url) {
    var h = 0;
    for (final cu in url.codeUnits) {
      h = ((h << 5) - h + cu) & 0x1FFFFFFFFFFFFF;
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
