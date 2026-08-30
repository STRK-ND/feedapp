/// SQLite-backed article store.
///
/// Replaces the previous single-JSON-blob persistence (one
/// `flutter_secure_storage` value holding every article). Per-row storage
/// means:
/// - toggling save/read updates ONE row instead of rewriting the entire
///   multi-hundred-KB blob on every interaction;
/// - a corrupt record is skipped at read time instead of risking the feed;
/// - future features (full-text search, per-source queries, history) get
///   a real query surface.
///
/// Payloads stay JSON-encoded [Article] maps so the model layer and the
/// worker contract are untouched — only the persistence mechanism moved.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/article.dart';
import '../utils/constants.dart';

class FeedDatabase {
  FeedDatabase({Database? db, String? path})
    : _dbOrNull = db,
      path = path ?? 'curated_feeds.db';

  /// Injectable for tests (in-memory ffi databases).
  final Database? _dbOrNull;
  Database? _opened;

  /// File name inside the platform default databases directory.
  final String path;

  static const String _articlesTable = 'articles';
  static const String _savedTable = 'saved_articles';

  Future<Database> _open() async {
    final existing = _opened;
    if (existing != null && existing.isOpen) return existing;

    final Database db;
    final injected = _dbOrNull;
    if (injected != null) {
      db = injected;
      // In-memory databases are owned by the test; don't cache-close them.
      return _ensureTables(db);
    }

    final dirPath = path == inMemoryDatabasePath
        ? ''
        : '${await getDatabasesPath()}/';
    final opened = await openDatabase(
      '$dirPath$path',
      version: 2,
      onCreate: (db, version) => _createTables(db),
      onUpgrade: migrate,
    );
    _opened = opened;
    // Idempotent guard: a crash mid-create leaves no tables behind.
    return _ensureTables(opened);
  }

  Future<Database> _ensureTables(Database db) async {
    await _createTables(db);
    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_articlesTable (
        id TEXT PRIMARY KEY,
        pub_date INTEGER NOT NULL,
        payload TEXT NOT NULL,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_savedTable (
        id TEXT PRIMARY KEY,
        pub_date INTEGER NOT NULL,
        payload TEXT NOT NULL,
        position INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// v1 → v2: adds the `updated_at` clock column used by cloud-sync
  /// last-write-wins merges. Legacy rows read as 0 so remote state wins
  /// on the first sync after upgrade.
  @visibleForTesting
  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $_articlesTable ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $_savedTable ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  /// Replace the whole cached-feed set. The newest-[AppConfig.maxCachedArticles]
  /// articles by pubDate win, mirroring the old blob behaviour.
  ///
  /// Content refreshes must NOT bump row clocks: the cloud-sync merge uses
  /// `updated_at` as the triage-state LWW clock, so a refresh that stamped
  /// `now` on every row would re-push the whole identical cache to Firestore
  /// on the next sync. Existing rows keep their clock; brand-new rows read
  /// 0 (remote wins / pushed only once touched) — same semantics as the
  /// v1→v2 migration for legacy rows.
  Future<void> saveArticles(List<Article> articles) async {
    final db = await _open();
    // Cap in Dart before writing: keeps SQL trivially portable.
    final sorted = List<Article>.from(articles)
      ..sort((a, b) {
        final c = b.pubDate.compareTo(a.pubDate);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
    final kept = sorted.take(AppConfig.maxCachedArticles).toList();

    // Capture the clocks we must preserve before the delete below.
    final existing = <String, int>{};
    try {
      final rows = await db.query(_articlesTable, columns: ['id', 'updated_at']);
      for (final r in rows) {
        existing[r['id'] as String] = (r['updated_at'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('[FeedDatabase] clock capture failed (treating as empty): $e');
    }

    await db.transaction((txn) async {
      await txn.delete(_articlesTable);
      final batch = txn.batch();
      for (final a in kept) {
        batch.insert(_articlesTable, {
          'id': a.id,
          'pub_date': a.pubDate.millisecondsSinceEpoch,
          'payload': encodeArticle(a),
          'updated_at': existing[a.id] ?? 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Article>> loadArticles() => _loadAll(_articlesTable);

  /// Replace or insert one row in the articles table. The triage hot
  /// path: read/save flags live inside the payload, so a flag change is
  /// a single-row rewrite instead of replacing up to
  /// [AppConfig.maxCachedArticles] rows on every swipe.
  Future<void> upsertArticle(Article article) async {
    final db = await _open();
    await db.insert(_articlesTable, {
      'id': article.id,
      'pub_date': article.pubDate.millisecondsSinceEpoch,
      'payload': encodeArticle(article),
      'updated_at': _nowMs(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Upsert several article rows in one transaction — bulk flag flips
  /// (mark-all-read / undo) persist only the rows that changed.
  ///
  /// [clocks] lets the cloud-sync pull path adopt the REMOTE per-row clock:
  /// stamping the local wall clock here would make every pulled row look
  /// locally newer than the cloud doc, and the next sync would push the
  /// identical payload straight back (write amplification, forever).
  Future<void> upsertArticles(
    List<Article> articles, {
    Map<String, int>? clocks,
  }) async {
    final db = await _open();
    await db.transaction((txn) async {
      final batch = txn.batch();
      final now = _nowMs();
      for (final a in articles) {
        batch.insert(_articlesTable, {
          'id': a.id,
          'pub_date': a.pubDate.millisecondsSinceEpoch,
          'payload': encodeArticle(a),
          'updated_at': clocks?[a.id] ?? now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  /// Replace or insert one row in the saved table. A newly-saved article
  /// goes to the front (most-recently-saved first) by shifting existing
  /// positions; re-saving an already-saved article keeps its position.
  Future<void> upsertSavedArticle(Article article) async {
    final db = await _open();
    await db.transaction((txn) async {
      final row = {
        'id': article.id,
        'pub_date': article.pubDate.millisecondsSinceEpoch,
        'payload': encodeArticle(article),
        'updated_at': _nowMs(),
      };
      final existing = await txn.query(
        _savedTable,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [article.id],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await txn.update(
          _savedTable,
          row,
          where: 'id = ?',
          whereArgs: [article.id],
        );
      } else {
        await txn.rawUpdate('UPDATE $_savedTable SET position = position + 1');
        await txn.insert(_savedTable, {
          ...row,
          'position': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Flip a local row to unsaved (payload flag + saved-table row). Pulls
  /// use this to apply remote deletion tombstones; returns the flipped
  /// article so the UI path can push the updated payload, or null when
  /// there was no row / it was not saved.
  Future<Article?> markUnsaved(String id) async {
    final db = await _open();
    Article? flipped;
    await db.transaction((txn) async {
      final rows = await txn.query(
        _articlesTable,
        columns: ['payload'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        try {
          final a = decodeArticle(rows.first['payload'] as String);
          if (a.isSaved) {
            flipped = a.copyWith(isSaved: false);
            await txn.update(
              _articlesTable,
              {'payload': encodeArticle(flipped!), 'updated_at': _nowMs()},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        } catch (e) {
          debugPrint('[FeedDatabase] markUnsaved payload decode failed: $e');
        }
      }
      await txn.delete(_savedTable, where: 'id = ?', whereArgs: [id]);
    });
    return flipped;
  }

  /// Replace the saved set wholesale; [articles] order is preserved via a
  /// position column (the UI treats the list as most-recently-saved first).
  Future<void> saveSavedArticles(List<Article> articles) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete(_savedTable);
      final batch = txn.batch();
      final now = _nowMs();
      var pos = 0;
      for (final a in articles) {
        batch.insert(_savedTable, {
          'id': a.id,
          'pub_date': a.pubDate.millisecondsSinceEpoch,
          'payload': encodeArticle(a),
          'position': pos++,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Article>> loadSavedArticles() async {
    final rows = await _loadRows(_savedTable, orderBy: 'position ASC');
    return rows;
  }

  /// id → updated_at (epoch ms) for every row in the articles table.
  /// Cloud-sync merge input: missing/legacy rows read as 0 so remote wins.
  Future<Map<String, int>> loadArticleTimestamps() async {
    try {
      final db = await _open();
      final rows = await db.query(
        _articlesTable,
        columns: ['id', 'updated_at'],
      );
      return {
        for (final r in rows) r['id'] as String: (r['updated_at'] as int?) ?? 0,
      };
    } catch (e) {
      debugPrint('[FeedDatabase] loadArticleTimestamps failed: $e');
      return {};
    }
  }

  Future<void> clearFeedCache() async {
    final db = await _open();
    await db.delete(_articlesTable);
  }

  Future<void> clearAll() async {
    final db = await _open();
    await db.delete(_articlesTable);
    await db.delete(_savedTable);
  }

  Future<void> close() async {
    await _opened?.close();
    _opened = null;
  }

  // ---------------------------------------------------------------------

  Future<List<Article>> _loadAll(String table) =>
      _loadRows(table, orderBy: 'pub_date DESC, id ASC');

  Future<List<Article>> _loadRows(
    String table, {
    required String orderBy,
  }) async {
    final db = await _open();
    try {
      final rows = await db.query(table, orderBy: orderBy);
      final articles = <Article>[];
      for (final row in rows) {
        try {
          articles.add(decodeArticle(row['payload'] as String));
        } catch (e) {
          // One bad row must not take down the whole list.
          debugPrint('[FeedDatabase] skipping corrupt row in $table: $e');
        }
      }
      return articles;
    } catch (e) {
      debugPrint('[FeedDatabase] load failed ($table): $e');
      return [];
    }
  }

  static String encodeArticle(Article a) {
    // Article.toJson already produces a stable map; reuse it verbatim.
    return articlePayloadJson(a.toJson());
  }

  static Article decodeArticle(String payload) {
    return Article.fromJson(decodeArticlePayload(payload));
  }
}

// Small indirections keep json import out of the class header clutter.
String articlePayloadJson(Map<String, dynamic> json) => jsonEncode(json);
Map<String, dynamic> decodeArticlePayload(String payload) =>
    jsonDecode(payload) as Map<String, dynamic>;
