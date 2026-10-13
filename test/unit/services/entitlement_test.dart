import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/services/sync_hooks.dart';

// M-1 / F-2 regression tests — Pro entitlement trust boundary.
//
// `is_pro` used to ride inside the synced settings snapshot. Firestore
// rules let a user write their own documents, so a signed-in user could
// self-grant Pro (M-1); a not-yet-synced second device pushing its local
// `false` could revoke a purchase made elsewhere (F-2). Both directions
// had one root cause: the entitlement travelled in a client-writable
// channel. The fix moved the only sanctioned cloud->local write to
// CloudSyncService._restoreProFlag and removed the key from the sync
// transport. These tests pin that contract at the SettingsService layer.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M-1/F-2: entitlement never travels in the settings snapshot', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('snapshotForSync() output does not contain is_pro', () async {
      final s = SettingsService();
      await s.setIsPro(true);

      final snapshot = await s.snapshotForSync();
      expect(
        snapshot.containsKey('is_pro'),
        isFalse,
        reason:
            'is_pro must never appear in the synced snapshot — a '
            'user-writable Firestore doc made it a self-grant path',
      );
      // The local flag itself still works (paywall path).
      expect(await s.getIsPro(), isTrue);
    });

    test(
      'restoreFromSync({is_pro: true}) leaves the local flag untouched',
      () async {
        final s = SettingsService();
        // A forged cloud snapshot (the M-1 reproduction wrote exactly this
        // document shape) must not unlock Pro through restoreFromSync.
        await s.restoreFromSync({'auto_refresh': true, 'is_pro': true});

        expect(
          await s.getIsPro(),
          isFalse,
          reason:
              'entitlement is never accepted from a synced snapshot; '
              'only CloudSyncService._restoreProFlag may set it',
        );
        // Preferences around it still restore.
        expect(await s.getAutoRefresh(), isTrue);
      },
    );

    test('restoreFromSync cannot flip is_pro in either direction', () async {
      final s = SettingsService();
      // Start Pro (set by the paywall / _restoreProFlag path).
      await s.setIsPro(true);

      // A cloud snapshot claiming false (the F-2 revoke direction) must
      // not unset it; one claiming true must not be the thing that set it.
      await s.restoreFromSync({'is_pro': false});
      expect(await s.getIsPro(), isTrue);

      await s.restoreFromSync({'is_pro': true});
      expect(await s.getIsPro(), isTrue);
    });

    test(
      'bumpEditionNumber() is a raw write (F-5): no sync hook fires',
      () async {
        final s = SettingsService();
        final hooks = _RecordingHooks();
        s.syncHooks = hooks;

        // Pre-seed a synced-setting write to prove the hook machinery works.
        await s.setAutoRefresh(false);
        expect(hooks.settingsChangedCalls, 1);

        await s.bumpEditionNumber();
        expect(
          hooks.settingsChangedCalls,
          1,
          reason:
              'the edition counter is device-local state; bumping it on '
              'every feed refresh used to push two identical Firestore '
              'documents (~48 pointless writes/day/user)',
        );
        expect(await s.getEditionNumber(), 2);
      },
    );
  });
}

/// Records hook invocations. [SyncHooks] has four members; the ones this
/// test does not assert on are no-ops.
class _RecordingHooks implements SyncHooks {
  int settingsChangedCalls = 0;
  int sourcesChangedCalls = 0;

  @override
  void onSettingsChanged() => settingsChangedCalls++;

  @override
  void onSourcesChanged() => sourcesChangedCalls++;

  @override
  void onArticleMutated(Article article) {}

  @override
  void onSavedArticleRemoved(String id) {}
}
