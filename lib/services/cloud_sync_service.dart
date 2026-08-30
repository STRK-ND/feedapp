import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/rss_source.dart';
import '../models/article.dart';
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
      debugPrint('[CloudSync] syncNow failed: $e');
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
    final deletions = ((stateData?['deletions'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    );

    final localTs = await _storage.loadArticleTimestamps();
    final merge = mergeArticles(
      remote: remote,
      localTimestamps: localTs,
      deletions: deletions,
    );

    if (merge.toUpsert.isNotEmpty) {
      await _storage.upsertArticles(merge.toUpsert);
    }
    for (final id in merge.toUnsave) {
      await _storage.unsaveArticleLocally(id);
    }

    // Rebuild the saved tab from the merged rows (front-insert order is
    // unknowable across devices; pubDate order is the stable fallback and
    // re-normalizes as the user saves more).
    if (merge.toUpsert.isNotEmpty || merge.toUnsave.isNotEmpty) {
      final merged = await _storage.loadArticles();
      final savedRows = merged.where((a) => a.isSaved).toList()
        ..sort((a, b) => b.pubDate.compareTo(a.pubDate));
      await _storage.saveSavedArticles(savedRows);
      if (!_articlesRestored.isClosed) _articlesRestored.add(null);
    }

    // Push local rows the cloud lacks or that beat the cloud clock
    // (covers changes made while signed out / offline).
    final all = await _storage.loadArticles();
    final toPush = [
      for (final a in all)
        if ((localTs[a.id] ?? 0) > (cloudTs[a.id] ?? 0)) a,
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
    if (data?['isPro'] == true && !(await _settings.getIsPro())) {
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
    final now = _now();
    final values = await _settings.snapshotForSync();
    await _settingsDoc(uid).set({'values': values, 'updatedAt': now});
    await _settings.setSettingsSyncTs(now);
    // Keep the account-level Pro flag aligned with the settings snapshot.
    await _userDoc(uid).set({
      'isPro': values['is_pro'] == true,
      'updatedAt': now,
    }, SetOptions(merge: true));
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
  Future<void> setPro({String? productId, String? purchaseToken}) async {
    final uid = _uid;
    if (uid == null) return;
    await _userDoc(uid).set({
      'isPro': true,
      'proProductId': productId,
      'proPurchaseToken': purchaseToken,
      'updatedAt': _now(),
    }, SetOptions(merge: true));
  }
}
