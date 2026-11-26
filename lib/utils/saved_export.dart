/// Markdown export of the Saved collection (market roadmap Tier 2,
/// feature 5) — the post-Pocket workflow: everything a user kept, with
/// their notes, in a format any notes app accepts. Pure: no I/O, no
/// Flutter, fully unit-testable.
library;

import '../models/article.dart';

/// Build the Markdown export for [articles] (the Saved list, in its
/// display order). Notes render as blockquotes; articles without a note
/// stay lean. Dates are ISO-8601 (yyyy-mm-dd) in UTC.
String buildSavedExportMarkdown(
  List<Article> articles, {
  DateTime? exportedAt,
}) {
  final now = exportedAt ?? DateTime.now().toUtc();
  final buffer = StringBuffer();
  buffer.writeln('# Curated Feeds — Saved articles');
  buffer.writeln();
  buffer.writeln(
    '_Exported ${_date(now)} · ${articles.length} '
    '${articles.length == 1 ? 'article' : 'articles'}_',
  );
  buffer.writeln();

  for (final a in articles) {
    buffer.writeln('## ${_clean(a.title)}');
    buffer.writeln();
    final meta = <String>[
      _clean(a.sourceName),
      _date(a.pubDate.toUtc()),
    ].join(' · ');
    buffer.writeln(meta);
    if (a.link.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(a.link);
    }
    final note = a.userNote.trim();
    if (note.isNotEmpty) {
      buffer.writeln();
      // Multi-line notes become consecutive blockquote lines.
      for (final line in note.split('\n')) {
        buffer.writeln('> ${_clean(line)}');
      }
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
  }

  return buffer.toString().trimRight();
}

/// Strip Markdown-significant leading characters from user/feed content
/// so a title or note line can never forge headings, list items or
/// blockquotes inside the export.
String _clean(String text) {
  return text.replaceFirst(RegExp(r'^[\s>#*\-]+'), '').trim();
}

String _date(DateTime utc) {
  final m = utc.month.toString().padLeft(2, '0');
  final d = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$m-$d';
}
