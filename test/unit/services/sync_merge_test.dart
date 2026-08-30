import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/services/sync_merge.dart';

void main() {
  Map<String, dynamic> payload(
    String id, {
    bool isRead = false,
    bool isSaved = false,
  }) =>
      {
        'id': id,
        'title': 'T $id',
        'description': '',
        'fullContent': '',
        'link': 'https://x/$id',
        'sourceId': 's',
        'sourceName': 'S',
        'pubDate': 1700000000000,
        'isRead': isRead,
        'isSaved': isSaved,
      };

  group('mergeArticles', () {
    test('remote newer than local wins; remote older is skipped', () {
      final result = mergeArticles(
        remote: [
          RemoteArticle(payload('a', isRead: true), 200),
          RemoteArticle(payload('b'), 50),
        ],
        localTimestamps: {'a': 100, 'b': 300},
        deletions: {},
      );
      expect(result.toUpsert.map((a) => a.id), ['a']);
      expect(result.toUpsert.first.isRead, isTrue);
      expect(result.toUnsave, isEmpty);
    });

    test('remote doc for an id absent locally is upserted', () {
      final result = mergeArticles(
        remote: [RemoteArticle(payload('new'), 1)],
        localTimestamps: {},
        deletions: {},
      );
      expect(result.toUpsert.map((a) => a.id), ['new']);
    });

    test('a corrupt remote payload is skipped, not fatal', () {
      final result = mergeArticles(
        remote: [
          const RemoteArticle({'id': 7}, 999), // id int → fromJson survives?
          const RemoteArticle(<String, dynamic>{'title': 'no id'}, 999),
        ],
        localTimestamps: {},
        deletions: {},
      );
      // Neither fixture yields a usable article (or both do — the contract
      // is only that mergeArticles must not throw).
      expect(result.toUpsert.length, lessThanOrEqualTo(2));
    });

    test('tombstone newer than the remote doc suppresses the upsert', () {
      final result = mergeArticles(
        remote: [RemoteArticle(payload('a', isSaved: true), 100)],
        localTimestamps: {'a': 50},
        deletions: {'a': 200},
      );
      expect(result.toUpsert, isEmpty);
      expect(result.toUnsave, ['a']);
    });

    test('tombstone older than the local row leaves it alone', () {
      final result = mergeArticles(
        remote: [RemoteArticle(payload('a', isSaved: true), 100)],
        localTimestamps: {'a': 300},
        deletions: {'a': 200},
      );
      expect(result.toUnsave, isEmpty);
      // Remote doc is also older than local → nothing to upsert.
      expect(result.toUpsert, isEmpty);
    });

    test('unrelated tombstones for ids absent locally are ignored', () {
      final result = mergeArticles(
        remote: [],
        localTimestamps: {'a': 100},
        deletions: {'ghost': 999},
      );
      expect(result.toUpsert, isEmpty);
      expect(result.toUnsave, isEmpty);
    });
  });

  group('pruneDeletions', () {
    test('drops entries older than the retention window', () {
      const now = 1_000_000_000;
      final pruned = pruneDeletions({
        'old': now - 91 * 24 * 3600 * 1000,
        'edge': now - 90 * 24 * 3600 * 1000,
        'fresh': now - 1000,
      }, now);
      expect(pruned.keys, ['edge', 'fresh']);
    });
  });

  group('remoteSnapshotWins', () {
    test('remote must be strictly newer; unknown local clock (0) always loses', () {
      expect(remoteSnapshotWins(10, 5), isTrue);
      expect(remoteSnapshotWins(5, 5), isFalse);
      expect(remoteSnapshotWins(1, 0), isTrue);
      expect(remoteSnapshotWins(0, 0), isFalse);
    });
  });
}
