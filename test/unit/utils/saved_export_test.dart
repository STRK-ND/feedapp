// Saved-collection Markdown export (Tier 2, feature 5): format contract,
// note rendering, and injection safety — plus the userNote payload
// roundtrip the export depends on.
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/utils/saved_export.dart';

Article makeArticle(
  String title, {
  String sourceName = 'The Verge',
  String note = '',
  String link = 'https://example.com/a',
}) {
  return Article(
    id: 'a-${title.hashCode}',
    title: title,
    description: 'Description',
    fullContent: '',
    link: link,
    sourceId: 'verge',
    sourceName: sourceName,
    pubDate: DateTime.utc(2026, 3, 5),
    userNote: note,
  );
}

void main() {
  group('buildSavedExportMarkdown', () {
    test('header, count and per-article sections', () {
      final md = buildSavedExportMarkdown([
        makeArticle('First post'),
        makeArticle('Second post'),
      ], exportedAt: DateTime.utc(2026, 12, 1));

      expect(md, startsWith('# Curated Feeds — Saved articles'));
      expect(md, contains('_Exported 2026-12-01 · 2 articles_'));
      expect(md, contains('## First post'));
      expect(md, contains('The Verge · 2026-03-05'));
      expect(md, contains('https://example.com/a'));
      expect(md, contains('## Second post'));
    });

    test('singular count for one article', () {
      final md = buildSavedExportMarkdown([
        makeArticle('Only one'),
      ], exportedAt: DateTime.utc(2026, 12, 1));
      expect(md, contains('1 article_'));
    });

    test('notes render as blockquotes, multi-line supported', () {
      final md = buildSavedExportMarkdown([
        makeArticle('With note', note: 'First line\nSecond line'),
      ]);
      expect(md, contains('> First line'));
      expect(md, contains('> Second line'));
    });

    test('articles without a note stay lean', () {
      final md = buildSavedExportMarkdown([makeArticle('No note')]);
      expect(md, isNot(contains('>')));
    });

    test('content cannot forge Markdown structure', () {
      final md = buildSavedExportMarkdown([
        makeArticle('# Forged heading'),
        makeArticle('Note injection', note: '> forged quote\n- forged list'),
      ]);
      // A '#'-prefixed title cannot forge a deeper heading.
      expect(md, isNot(contains('## # Forged')));
      // Note lines are always blockquoted — list/heading syntax inside a
      // note can never escape the quote.
      expect(md, isNot(contains('\n- forged list')));
      expect(md, contains('> forged quote'));
      // The sanitized text is still present.
      expect(md, contains('Forged heading'));
    });
  });

  group('userNote payload roundtrip', () {
    test('toJson/fromJson preserve the note', () {
      final a = makeArticle('Roundtrip', note: 'Remember this');
      final restored = Article.fromJson(Article.fromJson(a.toJson()).toJson());
      expect(restored.userNote, 'Remember this');
    });

    test('legacy payloads without userNote read as empty', () {
      final json = makeArticle('Legacy').toJson()..remove('userNote');
      expect(Article.fromJson(json).userNote, '');
    });

    test('copyWith carries and replaces the note', () {
      final a = makeArticle('Copy');
      expect(a.copyWith().userNote, '');
      expect(a.copyWith(userNote: 'new').userNote, 'new');
    });
  });
}
