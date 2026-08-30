/// Pure cloud-sync merge logic.
///
/// No Firebase imports — everything here is plain data in/out so the
/// last-write-wins rules are unit-testable without mocking Firestore.
///
/// Clock note: timestamps are client epoch-ms. Devices with skewed clocks
/// can resolve a conflict against the older edit; acceptable for a
/// single-user, few-devices app. Upgrade path: per-field server timestamps.
library;

import '../models/article.dart';

/// One document from `users/{uid}/articles/{articleId}`.
class RemoteArticle {
  final Map<String, dynamic>
  payload; // Article JSON as stored by the push path.
  final int updatedAt; // client epoch-ms of the last remote write.

  const RemoteArticle(this.payload, this.updatedAt);
}

/// Result of merging remote state into the local store.
class ArticleMergeResult {
  /// Remote rows that beat the local row (remote newer, or local missing).
  final List<Article> toUpsert;

  /// Local rows tombstoned remotely after their last local write — the
  /// caller flips them to unsaved locally.
  final List<String> toUnsave;

  const ArticleMergeResult(this.toUpsert, this.toUnsave);
}

/// Merge remote article docs + deletion tombstones against local row clocks.
///
/// Rules:
/// - remote doc newer than the local row (or local row absent) → upsert;
/// - a tombstone newer than the remote doc suppresses that doc (the article
///   was unsaved remotely after the doc was written);
/// - a tombstone newer than the local row's clock unsaves the local row.
ArticleMergeResult mergeArticles({
  required List<RemoteArticle> remote,
  required Map<String, int> localTimestamps,
  required Map<String, int> deletions,
}) {
  final toUpsert = <Article>[];
  for (final r in remote) {
    final Article a;
    try {
      a = Article.fromJson(r.payload);
    } catch (_) {
      continue; // one corrupt doc must not break the merge
    }
    final delTs = deletions[a.id];
    if (delTs != null && delTs > r.updatedAt) continue;
    if (r.updatedAt > (localTimestamps[a.id] ?? 0)) {
      toUpsert.add(a);
    }
  }

  final toUnsave = <String>[];
  deletions.forEach((id, deletedAt) {
    final localTs = localTimestamps[id];
    if (localTs != null && deletedAt > localTs) {
      toUnsave.add(id);
    }
  });

  return ArticleMergeResult(toUpsert, toUnsave);
}

/// Drop tombstones older than [maxAge] so the deletions map cannot grow
/// without bound.
Map<String, int> pruneDeletions(
  Map<String, int> deletions,
  int nowMs, {
  Duration maxAge = const Duration(days: 90),
}) {
  final cutoff = nowMs - maxAge.inMilliseconds;
  return Map<String, int>.fromEntries(
    deletions.entries.where((e) => e.value >= cutoff),
  );
}

/// Whole-document last-write-wins for the settings/sources snapshot docs.
/// Returns true when [remoteUpdatedAt] beats [localUpdatedAt] (0 = unknown),
/// meaning the caller should restore the remote document locally.
bool remoteSnapshotWins(int remoteUpdatedAt, int localUpdatedAt) =>
    remoteUpdatedAt > localUpdatedAt;
