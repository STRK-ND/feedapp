import 'package:flutter/material.dart';

/// RSS Feed Source Model
class RssSource {
  final String id;
  final String name;
  final String url;
  final String category;
  final Color color;
  final IconData icon;

  RssSource({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'category': category,
      'color': color.toARGB32(),
      'icon': icon.codePoint,
    };
  }

  factory RssSource.fromJson(Map<String, dynamic> json) {
    return RssSource(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      url: json['url'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      color: Color(json['color'] as int? ?? 0xFF000000),
      icon: IconData(json['icon'] as int? ?? 0xE000, fontFamily: 'MaterialIcons'),
    );
  }

  RssSource copyWith({
    String? id,
    String? name,
    String? url,
    String? category,
    Color? color,
    IconData? icon,
  }) {
    return RssSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      category: category ?? this.category,
      color: color ?? this.color,
      icon: icon ?? this.icon,
    );
  }
}
