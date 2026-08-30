import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/services/feed_database.dart';

// Clock-contract regression tests for the cloud-sync LWW merge.
//
// `updated_at` is the per-row triage clock the sync engine compares against
// the cloud `updatedAt`. Two paths used to break the contract (audit fix):
//   - upsertArticles stamped local `now` on PULLED rows → the next sync saw
//     the pulled row as locally newer and pushed the identical payload back
//     to Firestore, ping-ponging on every other sync forever;
//   - saveArticles (full cache replace on every feed refresh) stamped `now`
//     on EVERY row → the next sync re-uploaded the entire untouched cache.
// Both now preserve/adopt explicit clocks; these tests pin the contract.

int _dbCounter = 0;

Future<FeedDatabase> makeDb() async {
  sqfliteFfiInit();
  final dir = await Directory.systemTemp.createTemp('curatedfeeds_test');
  final db = await databaseFactoryFfi.openDatabase(
    '${dir.path}${Platform.pathSeparator}feed-${_dbCounter++}.db',
  );
  return FeedDatabase(db: db);
}

Article makeArticle({
  required String id,
  bool isSaved = false,
  bool isRead = false,
}) {
  return Article(
    id: id,
    title: 'Article $id',
    description: 'Description $id',
    fullContent: 'Full content $id',
    link: 'https://example.com/$id',
    sourceId: 'test',
    sourceName: 'Test Source',
    pubDate: DateTime.utc(2026, 1, 1),
    isSaved: isSaved,
    isRead: isRead,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('upsertArticles clock contract', () {
    test('pulled rows adopt the remote clock, not the local wall clock', () async {
      final db = await makeDb();
      final remote = {'a1': 1000, 'a2': 2000};
      await db.upsertArticles(
        [makeArticle(id: 'a1'), makeArticle(id: 'a2')],
        clocks: remote,
      );

      final clocks = await db.loadArticleTimestamps();
      // If these ever come back as "now", every sync pushes the identical
      // payload back to the cloud — the echo bug.
      expect(clocks['a1'], 1000);
      expect(clocks['a2'], 2000);
    });

    test('rows without an explicit clock fall back to the local clock', () async {
      final db = await makeDb();
      final before = DateTime.now().millisecondsSinceEpoch;
      await db.upsertArticles([makeArticle(id: 'a1', isRead: true)]);
      final clocks = await db.loadArticleTimestamps();
      expect(clocks['a1']! >= before, isTrue);
    });
  });

  group('saveArticles clock contract', () {
    test('content refresh preserves existing row clocks', () async {
      final db = await makeDb();
      await db.upsertArticles(
        [makeArticle(id: 'a1', isRead: true)],
        clocks: {'a1': 5555},
      );

      // Feed refresh rewrites the whole cached set with fresh content.
      await db.saveArticles([makeArticle(id: 'a1', isRead: true)]);
      final clocks = await db.loadArticleTimestamps();
      expect(clocks['a1'], 5555);
    });

    test('brand-new rows from a refresh read clock 0 (remote wins, untouched rows never push)', () async {
      final db = await makeDb();
      await db.saveArticles([makeArticle(id: 'fresh')]);
      final clocks = await db.loadArticleTimestamps();
      expect(clocks['fresh'], 0);
    });
  });
}
