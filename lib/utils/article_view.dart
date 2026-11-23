/// Presentation data derived from an [Article].
///
/// Every card that shows a source dot or a dateline used to carry its own
/// copy of the parsing rule, so a palette or format change had to be made in
/// four files. Both live here once, next to the model they read.
library;

import 'package:flutter/material.dart';

import '../models/article.dart';
import 'category_accent.dart';
import 'design_tokens.dart';

/// Source brand colour for an article: the hex the worker embedded, else the
/// category accent, else the amber attention colour.
Color articleAccent(String? hex, {String? category}) {
  final cleaned = hex?.replaceFirst('#', '');
  if (cleaned != null && cleaned.length == 6) {
    final value = int.tryParse('0xFF$cleaned');
    if (value != null) return Color(value);
  }
  return CategoryAccent.forCategory(category) ?? AppColors.primary;
}

/// Concise editorial dateline: `08/12 · 14:03`, `YESTERDAY`, `5D AGO`, or
/// `08/12/26`.
String formatDateline(DateTime dt, {DateTime? now}) {
  final today = _dayOf(now ?? DateTime.now());
  final diff = today.difference(_dayOf(dt)).inDays;
  if (diff == 0) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${_dayMonth(dt)} · $hh:$mm';
  }
  if (diff == 1) return 'YESTERDAY';
  if (diff < 7) return '${diff}D AGO';
  return '${_dayMonth(dt)}/${(dt.year % 100).toString().padLeft(2, '0')}';
}

String _dayMonth(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

extension ArticlePresentation on Article {
  /// Colour of the article's source dot.
  Color get accent => articleAccent(sourceColor, category: sourceCategory);

  /// Compact dateline for list and grid rows.
  String get dateline => formatDateline(pubDate);
}
