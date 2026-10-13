import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/rss_source.dart';
import '../models/article.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import 'posthog_service.dart';
import 'settings_service.dart';
import 'storage_service.dart';
import 'sync_hooks.dart';
import 'sync_merge.dart';

/// Mirrors user data between the local stores (sqflite + shared prefs, the
/// source of truth for the UI) and Firestore `users/{uid}` documents.
///
/// Push: local mutations arrive via [SyncHooks] — article rows write
/// immediately, snapshot docs (settings/sources) are debounced. Pull: on
/// sign-in and on every app start while signed in, remote docs are merged
/// last-write-wins per row (local `updated_at` column vs remote
/// `updatedAt`). Pull writes go through the hooks-free [StorageService]
/// instance so they never echo back here.
///
/// ponytail: snapshot docs are whole-document LWW and tombstones live in
/// one `sync_state` map — hobby-scale assumptions (1 MB doc limit). Split
/// per-field/per-doc only if a user outgrows it.
class CloudSyncService implements SyncHooks {
  CloudSyncService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required StorageService storage,
    required SettingsService settings,
  }) : _auth = auth,
       _firestore = firestore,
       _storage = storage,
       _settings = settings;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StorageService _storage;
  final SettingsService _settings;

  final StreamController<void> _settingsRestored =
      StreamController<void>.broadcast();
  final StreamController<void> _articlesRestored =
      StreamController<void>.broadcast();

  /// Fired when a pull changed local settings — the UI reloads.
  Stream<void> get settingsRestored => _settingsRestored.stream;

  /// Fired when a pull/push changed local articles — the feed reloads.
  Stream<void> get articlesRestored => _articlesRestored.stream;

  DateTime? _lastSyncedAt;
  Timer? _settingsDebounce;
  Timer? _sourcesDebounce;
  bool _syncing = false;
  StreamSubscription<User?>? _authSub;

  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get _uid => _auth.currentUser?.uid;

  /// Start reacting to sign-in/sign-out for the process lifetime.
  /// authStateChanges replays the current user on listen, so this covers
  /// app-start sync as well. Called once from the service locator.
  Future<void> init() async {
    _authSub ??= _auth.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(PostHogService.identify(user.uid));
        unawaited(syncNow());
      } else {
        PostHogService.resetUser();
        onSignedOut();
      }
    });
  }

  CollectionReference<Map<String, dynamic>> _articlesCol(String uid) =>
      _firestore.collection('users/$uid/articles');
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.doc('users/$uid');
  DocumentReference<Map<String, dynamic>> _settingsDoc(String uid) =>
      _firestore.doc('users/$uid/settings/main');
  DocumentReference<Map<String, dynamic>> _sourcesDoc(String uid) =>
      _firestore.doc('users/$uid/sources/main');
  DocumentReference<Map<String, dynamic>> _syncStateDoc(String uid) =>
      _firestore.doc('users/$uid/sync_state/main');

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------------------------------------------------------------------
  // Sync entry point (sign-in / app start while signed in)
  // ---------------------------------------------------------------------

  Future<void> syncNow() async {
    final user = _auth.currentUser;
    if (user == null || _syncing) return;
    _syncing = true;
    try {
      await _ensureUserDoc(user);
      await _reconcileSettings(user.uid);
      await _reconcileSources(user.uid);
      await _reconcileArticles(user.uid);
      _lastSyncedAt = DateTime.now();
    } catch (e) {
      // Sync failures are invisible by design (offline-first); route them
      // through the error handler so release builds still report to Sentry.
      unawaited(ErrorHandler.logError('Cloud sync failed', error: e));
    } finally {
      _syncing = false;
    }
  }

  /// Stop pushing after sign-out; local data stays as-is.
  void onSignedOut() {
    _settingsDebounce?.cancel();
    _sourcesDebounce?.cancel();
    _lastSyncedAt = null;
  }

  Future<void> _ensureUserDoc(User user) async {
    final doc = _userDoc(user.uid);
    if ((await doc.get()).exists) return;
    final now = _now();
    await doc.set({
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'isPro': false,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  // ---------------------------------------------------------------------
  // Pull / reconcile
  // ---------------------------------------------------------------------

  Future<void> _reconcileSettings(String uid) async {
    final data = (await _settingsDoc(uid).get()).data();
    final cloudTs = (data?['updatedAt'] as int?) ?? 0;
    final localTs = await _settings.getSettingsSyncTs();
    if (cloudTs == 0 && localTs == 0) {
      await _pushSettings(uid); // first sync ever: this device wins
      return;
    }
    if (cloudTs > localTs) {
      final values =
          (data?['values'] as Map?)?.cast<String, Object?>() ?? const {};
      await _settings.restoreFromSync(values);
      await _settings.setSettingsSyncTs(cloudTs);
      await _restoreProFlag(uid);
      if (!_settingsRestored.isClosed) _settingsRestored.add(null);
    } else if (localTs > cloudTs) {
      await _pushSettings(uid);
    }
  }

  Future<void> _reconcileSources(String uid) async {
    final data = (await _sourcesDoc(uid).get()).data();
    final cloudTs = (data?['updatedAt'] as int?) ?? 0;
    final localTs = await _settings.getSourcesSyncTs();
    if (cloudTs == 0 && localTs == 0) {
      await _pushSources(uid); // first sync ever: this device wins
      return;
    }
    if (cloudTs > localTs) {
      final subs = ((data?['subscribedSourceIds'] as List?) ?? const [])
          .cast<String>()
          .toSet();
      final customs = ((data?['customSources'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) {
            try {
              return RssSource.fromJson(m.cast<String, dynamic>());
            } catch (_) {
              return null;
            }
          })
          .whereType<RssSource>()
          .toList();
      await _settings.restoreFromSync({
        'subscribed_source_ids': subs.toList(),
        'custom_sources': customs.map((s) => jsonEncode(s.toJson())).toList(),
      });
      await _settings.setSourcesSyncTs(cloudTs);
      if (!_settingsRestored.isClosed) _settingsRestored.add(null);
    } else if (localTs > cloudTs) {
      await _pushSources(uid);
    }
  }

  /// Reconciles the user's triage state against the cloud.
  ///
  /// Reads the FULL `users/{uid}/articles` collection (F-4, Option A):
  /// every document in it exists because the user touched that article —
  /// the push filter is `isRead || isSaved` — so the collection only ever
  /// grows, and the read cost scales with lifetime triage volume, not
  /// current state. Firestore offers no way to query "changed since" on a
  /// document field, so bounding this requires a structural schema change
  /// (collapse to a single sync_state doc — see F-4's Option B). Accepted
  /// as-is at current user volume; revisit if the bill or cold-start
  /// latency grows.
  Future<void> _reconcileArticles(String uid) async {
    final cloudSnap = await _articlesCol(uid).get();
    final cloudTs = <String, int>{};
    final remote = <RemoteArticle>[];
    for (final d in cloudSnap.docs) {
      final data = d.data();
      final ts = (data['updatedAt'] as int?) ?? 0;
      cloudTs[d.id] = ts;
      remote.add(
        RemoteArticle(
          (data['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
          ts,
        ),
      );
    }

    final stateData = (await _syncStateDoc(uid).get()).data();
    final deletionsRaw = ((stateData?['deletions'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    );
    // F-3: bound the tombstone map. pruneDeletions implements the 90-day
    // cap and is unit-tested, but was never wired in — the map grew by one
    // entry per unsave for the life of the account, and every sync paid
    // the read cost for all of it.
    final deletions = pruneDeletions(deletionsRaw, _now());
    if (deletions.length != deletionsRaw.length) {
      unawaited(
        _syncStateDoc(uid)
            .set({'deletions': deletions}, SetOptions(merge: true))
            .catchError((Object e) {
              debugPrint('[CloudSync] deletions prune write failed: $e');
            }),
      );
    }

    final localTs = await _storage.loadArticleTimestamps();
    final merge = mergeArticles(
      remote: remote,
      localTimestamps: localTs,
      deletions: deletions,
    );

    if (merge.toUpsert.isNotEmpty) {
      // Adopt the remote clock per row — see FeedDatabase.upsertArticles:
      // stamping local time here would re-push every pulled row forever.
      await _storage.upsertArticles(merge.toUpsert, clocks: cloudTs);
    }
    for (final id in merge.toUnsave) {
      await _storage.unsaveArticleLocally(id);
    }

    // Rebuild the saved tab from the merged rows. UNION with the rows
    // already in saved_articles (F-1 fix): rebuilding from the feed table
    // ALONE silently deleted any saved article that saveArticles' cap had
    // evicted from the feed table — the row vanished from the user's Saved
    // tab with no error. Anything already saved is user data; only an
    // explicit unsave (applied above via unsaveArticleLocally / merge
    // tombstones) may remove it, so rows absent from `merged` are kept.
    // Order: front-insert order is unknowable across devices — union rows
    // that lose the appeal get the oldest positions, pubDate order re-
    // normalizes as the user saves more.
    if (merge.toUpsert.isNotEmpty || merge.toUnsave.isNotEmpty) {
      final merged = await _storage.loadArticles();
      final savedRows = merged.where((a) => a.isSaved).toList();
      final known = await _storage.loadSavedArticles();
      final seen = {for (final a in savedRows) a.id};
      final keptSaved = <Article>[
        ...savedRows,
        for (final a in known)
          if (!seen.contains(a.id)) a,
      ]..sort((a, b) => b.pubDate.compareTo(a.pubDate));
      await _storage.saveSavedArticles(keptSaved);
      if (!_articlesRestored.isClosed) _articlesRestored.add(null);
    }

    // Push local rows the cloud lacks or that beat the cloud clock
    // (covers changes made while signed out / offline). Only touched rows
    // (read/saved state) sync — the cloud mirror exists for triage state,
    // and pushing the untouched cache would re-upload the identical feed
    // after every content refresh.
    final all = await _storage.loadArticles();
    final toPush = [
      for (final a in all)
        if ((a.isRead || a.isSaved) &&
            (localTs[a.id] ?? 0) > (cloudTs[a.id] ?? 0))
          a,
    ];
    if (toPush.isNotEmpty) {
      await _pushArticles(uid, toPush);
      if (!_articlesRestored.isClosed) _articlesRestored.add(null);
    }
  }

  Future<void> _pushArticles(String uid, List<Article> articles) async {
    for (var i = 0; i < articles.length; i += 400) {
      final end = (i + 400 < articles.length) ? i + 400 : articles.length;
      final batch = _firestore.batch();
      final now = _now();
      for (final a in articles.sublist(i, end)) {
        batch.set(_articlesCol(uid).doc(a.id), {
          'payload': a.toJson(),
          'updatedAt': now,
        });
      }
      await batch.commit();
    }
  }

  Future<void> _restoreProFlag(String uid) async {
    final data = (await _userDoc(uid).get()).data();
    // THIS is the single authoritative writer path for the Pro flag.
    // Entitlement never travels in the synced settings snapshot (M-1/F-2:
    // `is_pro` was removed from _syncedBoolKeys) — _restoreProFlag is the
    // only code that turns a cloud flag into a local one, and it holds the
    // verified-purchase rule for Play builds. If `is_pro` is ever re-added
    // to the synced keys, this method stops being the trust boundary.
    final cloudPro = data?['isPro'] == true;
    if (!cloudPro) return;
    if (AppConfig.isPlayStoreBuild && !(await _settings.getIsPro())) {
      debugPrint(
        '[CloudSync] Cloud Pro flag ignored on Play build without a '
        'verified local purchase.',
      );
      return;
    }
    if (!(await _settings.getIsPro())) {
      await _settings.setIsPro(true);
    }
  }

  // ---------------------------------------------------------------------
  // Push (SyncHooks) — signed-in only; Firestore queues while offline.
  // ---------------------------------------------------------------------

  @override
  void onArticleMutated(Article article) {
    final uid = _uid;
    if (uid == null) return;
    unawaited(
      _articlesCol(uid)
          .doc(article.id)
          .set({'payload': article.toJson(), 'updatedAt': _now()})
          .catchError((Object e) {
            debugPrint('[CloudSync] article push failed: $e');
          }),
    );
  }

  @override
  void onSavedArticleRemoved(String id) {
    final uid = _uid;
    if (uid == null) return;
    unawaited(
      _syncStateDoc(uid)
          .set({
            'deletions': {id: _now()},
          }, SetOptions(merge: true))
          .catchError((Object e) {
            debugPrint('[CloudSync] tombstone push failed: $e');
          }),
    );
  }

  @override
  void onSettingsChanged() {
    if (_uid == null) return;
    _settingsDebounce?.cancel();
    _settingsDebounce = Timer(const Duration(seconds: 3), () {
      final uid = _uid;
      if (uid == null) return;
      unawaited(_pushSettings(uid));
    });
  }

  @override
  void onSourcesChanged() {
    if (_uid == null) return;
    _sourcesDebounce?.cancel();
    _sourcesDebounce = Timer(const Duration(seconds: 3), () {
      final uid = _uid;
      if (uid == null) return;
      unawaited(_pushSources(uid));
    });
  }

  Future<void> _pushSettings(String uid) async {
    // F-5/F-2/M-1: does NOT mirror isPro onto the user doc. `setPro` is the
    // only writer of that field; re-deriving it from the local preference
    // meant a second, not-yet-synced device could silently revoke a
    // purchase made elsewhere (its local values['is_pro'] was still
    // false), and a forged snapshot could grant Pro for free.
    final now = _now();
    final values = await _settings.snapshotForSync();
    await _settingsDoc(uid).set({'values': values, 'updatedAt': now});
    await _settings.setSettingsSyncTs(now);
  }

  Future<void> _pushSources(String uid) async {
    final now = _now();
    final subs = await _settings.getSubscribedSourceIds();
    final customs = await _settings.getCustomSources();
    await _sourcesDoc(uid).set({
      'subscribedSourceIds': subs.toList(),
      'customSources': customs.map((s) => s.toJson()).toList(),
      'updatedAt': now,
    });
    await _settings.setSourcesSyncTs(now);
  }

  // ---------------------------------------------------------------------
  // Pro purchase (called from the paywall after Play verifies it)
  // ---------------------------------------------------------------------

  /// Persist a verified Pro purchase to the account so it survives
  /// reinstalls and follows the user across devices.
  ///
  /// I-2: the Play `purchaseToken` is deliberately NOT stored. It is a
  /// redeemable credential — anyone reading it can redeem the purchase
  /// again (refund fraud, or replay on a different account), and the
  /// purchase row in `users/{uid}` is readable by the signed-in user via
  /// the client SDK on every device. The entitlement flag plus the
  /// product id is all a restore needs: Play's own BillingClient is the
  /// authority that re-verifies the token, and `_restoreProFlag` reads
  /// back only the flag. Stopped passing the token from the paywall too,
  /// so the parameter is gone rather than silently ignored.
  Future<void> setPro({String? productId}) async {
    final uid = _uid;
    if (uid == null) return;
    await _userDoc(uid).set({
      'isPro': true,
      'proProductId': productId,
      'updatedAt': _now(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------
  // Account deletion (R-2 — Play policy: in-app deletion path required)
  // ---------------------------------------------------------------------

  /// Deletes every cloud document for [uid] ahead of `user.delete()`.
  ///
  /// The client SDK has no recursive delete (that is Admin-SDK/Cloud
  /// Function territory), so the known subcollections are enumerated and
  /// each wiped in ≤400-doc batches. ponytail: if a future subcollection
  /// is added under users/{uid}, add it here or it will be orphaned on
  /// deletion. Called BEFORE the auth record is removed (R-2): once
  /// `deleteUser()` succeeds the caller can no longer prove ownership of
  /// the data, so an orphaned tenant could never be cleaned up again.
  Future<void> purgeUserData(String uid) async {
    // Articles: batched delete; collection can be large, so page through
    // it with a limit instead of `get()` without one.
    for (;;) {
      final snap = await _articlesCol(uid).limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < 400) break;
    }

    // The four singleton docs (settings/main, sources/main,
    // sync_state/main) plus the user root. Deleting the root doc does NOT
    // cascade in Firestore — the subcollection docs above must already be
    // gone or they remain.
    await Future.wait<dynamic>([
      _settingsDoc(uid).delete(),
      _sourcesDoc(uid).delete(),
      _syncStateDoc(uid).delete(),
      _userDoc(uid).delete(),
    ]);
  }
}
