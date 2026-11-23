/// Per-category accent colours.
///
/// Separate from [AppColors] on purpose: these answer "what colour is
/// Science?", not "what is the app's surface colour". Anything that needs a
/// category's colour — a source tile, a section badge, the worker's
/// `color` fallback — reads it here, so the palette is never written twice.
library;

import 'package:flutter/material.dart';

class CategoryAccent {
  CategoryAccent._();

  static const Color tech = Color(0xFF60A5FA);
  static const Color news = Color(0xFFDC2626);
  static const Color science = Color(0xFF22D3EE);
  static const Color sports = Color(0xFF34D399);
  static const Color entertainment = Color(0xFF7C3AED);
  static const Color gaming = Color(0xFFA78BFA);

  /// Accent for [category], or null when the category has no palette entry
  /// (custom feeds, or a category the worker adds later). Callers own the
  /// fallback so this file never has to know a source's default colour.
  static Color? forCategory(String? category) => switch (category) {
    'Tech' => tech,
    'News' => news,
    'Science' => science,
    'Sports' => sports,
    'Entertainment' => entertainment,
    'Gaming' => gaming,
    _ => null,
  };
}
