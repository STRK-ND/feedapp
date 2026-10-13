import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/services/feed_database.dart';

// F-1 regression tests — the only data-loss finding in the audit.
//
// saveArticles caps the feed cache at AppConfig.maxCachedArticles rows by
// deleting everything older. The saved list is a second table referencing
// that state. When a saved article fell outside the cap it was evicted
// from `articles` (orphaning the saved row), and the cloud-sync rebuild —
// which read the feed table alone — then deleted the row from
// saved_articles outright. A user's saved article silently vanished.
//
// The fix (both halves are pinned here):
//   1. Eviction guard — saveArticles never evicts a row that
//      saved_articles still references (the cache may exceed the cap by
//      |saved|).
//   2. Union rebuild — the sync path unions feed-table saved rows with
//      rows already present in saved_articles, so omission can never
//      equal deletion. (Covered at the CloudSyncService level; this file
//      pins the storage-layer contract the rebuild depends on.)

int _dbCounter = 0;

Future<FeedDatabase> makeDb() async {
  sqfliteFfiInit();
  final dir = await Directory.systemTemp.createTemp('curatedfeeds_test');
  final db = await databaseFactoryFfi.openDatabase(
    '${dir.path}${Platform.pathSeparator}feed-cap-${_dbCounter++}.db',
  );
  return FeedDatabase(db: db);
}

Article makeArticle(String id, {bool isSaved = false, DateTime? pubDate}) {
  return Article(
    id: id,
    title: 'Article $id',
    description: 'Description $id',
    fullContent: 'Full content $id',
    link: 'https://example.com/$id',
    sourceId: 'test',
    sourceName: 'Test Source',
    pubDate: pubDate ?? DateTime.utc(2026, 1, 1),
    isSaved: isSaved,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('F-1: saved articles survive the cache cap', () {
    test('saveArticles keeps a saved article older than the newest '
        '${1100} rows (eviction guard)', () async {
      final db = await makeDb();

      // One 900-day-old SAVED article + enough fresh ones to push it
      // past the cap. (The audit's first probe used 999 fillers and
      // looked clean — a false negative. Keep the total strictly above
      // the cap with the saved row oldest.)
      final oldSaved = makeArticle(
        'old-saved',
        isSaved: true,
        pubDate: DateTime.utc(2024, 1, 1),
      );
      final fresh = List.generate(
        1100,
        (i) => makeArticle(
          'fresh-$i',
          pubDate: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
        ),
      );

      await db.saveArticles([oldSaved, ...fresh]);
      await db.upsertSavedArticle(oldSaved);

      // Feed refresh again — the cap pressure is what evicted the row
      // in the original defect.
      await db.saveArticles([oldSaved, ...fresh]);

      final articles = await db.loadArticles();
      final saved = await db.loadSavedArticles();

      expect(
        articles.any((a) => a.id == 'old-saved'),
        isTrue,
        reason:
            'the eviction guard must keep rows saved_articles '
            'references, even beyond maxCachedArticles',
      );
      expect(saved.any((a) => a.id == 'old-saved'), isTrue);

      // The clock must survive too: losing it made mergeArticles treat
      // the row as locally-stale and re-pull a stale remote doc.
      final clocks = await db.loadArticleTimestamps();
      expect(clocks.containsKey('old-saved'), isTrue);

      // Fresh rows are still capped: cache = cap + |saved|.
      expect(articles.length, lessThanOrEqualTo(1101));
    });

    test(
      'unsaved rows beyond the cap are still evicted (cap still works)',
      () async {
        final db = await makeDb();
        final articles = List.generate(
          1100,
          (i) => makeArticle(
            'n-$i',
            pubDate: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          ),
        );
        await db.saveArticles(articles);

        final loaded = await db.loadArticles();
        expect(loaded.length, 1000, reason: 'cap holds when nothing is saved');
        expect(
          loaded.any((a) => a.id == 'n-0'),
          isFalse,
          reason: 'oldest unsaved row is evicted',
        );
        expect(loaded.any((a) => a.id == 'n-1099'), isTrue);
      },
    );

    test('the union-rebuild contract: rows present only in saved_articles '
        'must survive a rebuild seeded from the feed table', () async {
      final db = await makeDb();

      // Simulate the pre-fix orphan: an old saved row exists in
      // saved_articles but was already evicted from the feed table by
      // an older build.
      final orphan = makeArticle(
        'orphan',
        isSaved: true,
        pubDate: DateTime.utc(2024, 6, 1),
      );
      await db.upsertSavedArticle(orphan);

      // The rebuild (mirrors CloudSyncService._reconcileArticles): union
      // feed-table saved rows with rows already in saved_articles.
      final merged = await db.loadArticles();
      final savedRows = merged.where((a) => a.isSaved).toList();
      final known = await db.loadSavedArticles();
      final seen = {for (final a in savedRows) a.id};
      final keptSaved = <Article>[
        ...savedRows,
        for (final a in known)
          if (!seen.contains(a.id)) a,
      ]..sort((a, b) => b.pubDate.compareTo(a.pubDate));
      await db.saveSavedArticles(keptSaved);

      final saved = await db.loadSavedArticles();
      expect(
        saved.any((a) => a.id == 'orphan'),
        isTrue,
        reason:
            'the union rebuild must keep rows the feed table no '
            'longer holds — only an explicit unsave removes user data',
      );
    });
  });
}
