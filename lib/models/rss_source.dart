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
}
