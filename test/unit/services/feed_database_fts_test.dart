// Full-text (body) search — FTS5 tables, v2→v3 migration backfill, and
// the index-maintenance contract: the index must always match what the
// reader can display, across every write path.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/services/feed_database.dart';

int _dbCounter = 0;

Future<FeedDatabase> makeDb() async {
  sqfliteFfiInit();
  final dir = await Directory.systemTemp.createTemp('curatedfeeds_fts');
  final db = await databaseFactoryFfi.openDatabase(
    '${dir.path}${Platform.pathSeparator}feed-fts-${_dbCounter++}.db',
  );
  return FeedDatabase(db: db);
}

Article makeArticle(
  String id, {
  String? title,
  String? description,
  String? fullContent,
  bool isSaved = false,
}) {
  return Article(
    id: id,
    title: title ?? 'Article $id',
    description: description ?? 'Description $id',
    fullContent: fullContent ?? 'Full content $id',
    link: 'https://example.com/$id',
    sourceId: 'test',
    sourceName: 'Test Source',
    pubDate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
    isSaved: isSaved,
  );
}

void main() {
  group('FTS body search', () {
    test(
      'saveArticles indexes bodies; search finds title, description and fullContent words',
      () async {
        final db = await makeDb();
        expect(
          db.ftsAvailableForTest,
          isTrue,
          reason:
              'the ffi SQLite build ships FTS5; if this fails the '
              'fallback path is untestable here',
        );

        await db.saveArticles([
          makeArticle('a1', title: 'Quantum Computing Advances'),
          makeArticle('a2', description: 'The qubits stayed coherent'),
          makeArticle('a3', fullContent: 'Deep body text about entanglement'),
        ]);

        final byTitle = await db.searchBodies('quantum');
        expect(byTitle, isNotNull);
        expect(byTitle!.map((h) => h.id), ['a1']);

        final byDescription = await db.searchBodies('coherent');
        expect(byDescription!.map((h) => h.id), ['a2']);

        final byBody = await db.searchBodies('entanglement');
        expect(byBody!.map((h) => h.id), ['a3']);

        // Snippet is populated around the match.
        expect(byBody.single.snippet, contains('entanglement'));
      },
    );

    test('multi-term queries AND together; terms are quoted', () async {
      expect(
        FeedDatabase.buildMatchQueryForTest('quantum computing'),
        '"quantum" AND "computing"',
      );
      expect(FeedDatabase.buildMatchQueryForTest('  '), isNull);
      // MATCH-syntax injection via quotes/parens is neutralized by quoting.
      expect(
        FeedDatabase.buildMatchQueryForTest('a" OR (b'),
        '"a" AND "or" AND "b"',
      );

      final db = await makeDb();
      await db.saveArticles([
        makeArticle('a1', title: 'Quantum computing advances'),
        makeArticle('a2', title: 'Quantum doubts'),
      ]);
      final both = await db.searchBodies('quantum computing');
      expect(both!.map((h) => h.id), ['a1']);
      final one = await db.searchBodies('doubts');
      expect(one!.map((h) => h.id), ['a2']);
    });

    test(
      'upsertArticle reindexes the row: old words drop, new words hit',
      () async {
        final db = await makeDb();
        final a = makeArticle('a1', title: 'Original headline');
        await db.saveArticles([a]);

        await db.upsertArticle(
          a.copyWith(title: 'Replacement headline', fullContent: 'zebra body'),
        );

        final original = await db.searchBodies('original');
      expect(original ?? const <BodySearchHit>[], isEmpty);
        final hits = await db.searchBodies('zebra');
        expect(hits!.map((h) => h.id), ['a1']);
      },
    );

    test(
      'saved list is indexed separately and searched with saved: true',
      () async {
        final db = await makeDb();
        await db.saveArticles([makeArticle('a1')]);
        await db.saveSavedArticles([
          makeArticle('s1', title: 'Saved pasta recipe', isSaved: true),
        ]);

        // Feed search does not see saved-table-only rows.
        final pasta = await db.searchBodies('pasta');
      expect(pasta ?? const <BodySearchHit>[], isEmpty);
        final savedHits = await db.searchBodies('pasta', saved: true);
        expect(savedHits!.map((h) => h.id), ['s1']);
      },
    );

    test(
      'saveSavedArticles rebuilds the saved index (unsave drops the hit)',
      () async {
        final db = await makeDb();
        await db.saveSavedArticles([
          makeArticle('s1', title: 'Saved pasta recipe', isSaved: true),
        ]);
        await db.saveSavedArticles([]);

        final pastaSaved = await db.searchBodies('pasta', saved: true);
      expect(pastaSaved ?? const <BodySearchHit>[], isEmpty);
      },
    );

    test(
      'markUnsaved reindexes the feed row and clears the saved index',
      () async {
        final db = await makeDb();
        final a = makeArticle('a1', title: 'pasta recipe');
        await db.saveArticles([a]);
        await db.upsertSavedArticle(a.copyWith(isSaved: true));

        await db.markUnsaved('a1');

        // Still findable in the feed index…
        final pasta = await db.searchBodies('pasta');
      expect(pasta ?? const <BodySearchHit>[], isNotEmpty);
        // …and gone from the saved index.
        final pastaSaved = await db.searchBodies('pasta', saved: true);
      expect(pastaSaved ?? const <BodySearchHit>[], isEmpty);
      },
    );

    test('clearFeedCache clears the feed index', () async {
      final db = await makeDb();
      await db.saveArticles([makeArticle('a1', title: 'pasta recipe')]);
      await db.clearFeedCache();
      final pasta = await db.searchBodies('pasta');
      expect(pasta ?? const <BodySearchHit>[], isEmpty);
    });

    test('empty query returns empty hits, not null', () async {
      final db = await makeDb();
      await db.saveArticles([makeArticle('a1')]);
      final hits = await db.searchBodies('   ');
      expect(hits, isNotNull);
      expect(hits, isEmpty);
    });
  });

  group('v2 → v3 migration backfill', () {
    test('existing v2 rows become searchable after migrate', () async {
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('curatedfeeds_mig');
      final raw = await databaseFactoryFfi.openDatabase(
        '${dir.path}${Platform.pathSeparator}feed-mig-${_dbCounter++}.db',
      );
      // Build the v2 schema by hand (no FTS tables).
      await raw.execute('''
        CREATE TABLE articles (
          id TEXT PRIMARY KEY,
          pub_date INTEGER NOT NULL,
          payload TEXT NOT NULL,
          updated_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await raw.execute('''
        CREATE TABLE saved_articles (
          id TEXT PRIMARY KEY,
          pub_date INTEGER NOT NULL,
          payload TEXT NOT NULL,
          position INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
      final legacy = makeArticle('old1', fullContent: 'prehistoric mammoths');
      await raw.insert('articles', {
        'id': legacy.id,
        'pub_date': legacy.pubDate.millisecondsSinceEpoch,
        'payload': FeedDatabase.encodeArticle(legacy),
        'updated_at': 0,
      });

      await FeedDatabase.migrate(raw, 2, 3);

      final db = FeedDatabase(db: raw);
      final hits = await db.searchBodies('mammoths');
      expect(hits!.map((h) => h.id), ['old1']);
    });
  });
}
