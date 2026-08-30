/// Cloud-sync push hooks.
///
/// Implemented by [CloudSyncService] and injected into the local
/// persistence layer (StorageService / SettingsService) so every user-data
/// mutation can be mirrored to Firestore. Nullable everywhere: tests and
/// signed-out usage simply leave the hook unset.
library;

import '../models/article.dart';

abstract class SyncHooks {
  /// A feed row changed (read flag, saved flag, or payload refresh).
  void onArticleMutated(Article article);

  /// A saved-article row was removed (unsave / dismiss) — record the
  /// deletion tombstone so other devices unsave too.
  void onSavedArticleRemoved(String id);

  /// Any non-source preference changed.
  void onSettingsChanged();

  /// Subscribed ids or custom sources changed.
  void onSourcesChanged();
}
