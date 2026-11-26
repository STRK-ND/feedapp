import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/utils/mute_filter.dart';

/// Muted-keywords regression: the notifier is the sole write-path, so the
/// normalize/cap contract and the live-notify behaviour are pinned here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService service;
  late SettingsNotifier notifier;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    service = SettingsService();
    notifier = SettingsNotifier(service);
    await notifier.loadSettings();
  });

  test('muted terms are empty by default', () {
    expect(notifier.mutedTerms, isEmpty);
  });

  test('muteTerm adds, persists and notifies', () async {
    var notified = 0;
    notifier.addListener(() => notified++);

    final added = await notifier.muteTerm('  Crypto ');

    expect(added, isTrue);
    expect(notifier.mutedTerms, equals(['crypto']));
    expect(notified, 1);
    expect(await service.getMutedTerms(), equals(['crypto']));
  });

  test(
    'muteTerm rejects empty and duplicate terms without notifying',
    () async {
      await notifier.muteTerm('crypto');
      var notified = 0;
      notifier.addListener(() => notified++);

      expect(await notifier.muteTerm('   '), isFalse);
      expect(await notifier.muteTerm('CRYPTO'), isFalse);
      expect(notified, 0);
      expect(notifier.mutedTerms, equals(['crypto']));
    },
  );

  test('muteTerm refuses past the cap', () async {
    await service.setMutedTerms(List.generate(maxMutedTerms, (i) => 't$i'));
    await notifier.loadSettings();

    expect(await notifier.muteTerm('overflow'), isFalse);
    expect(notifier.mutedTerms, hasLength(maxMutedTerms));
  });

  test(
    'unmuteTerm removes case-insensitively; unknown term is a no-op',
    () async {
      await notifier.muteTerm('crypto');

      await notifier.unmuteTerm('CRYPTO');
      expect(notifier.mutedTerms, isEmpty);

      await notifier.unmuteTerm('not-muted');
      expect(notifier.mutedTerms, isEmpty);
    },
  );

  test('loadSettings picks up persisted terms (cloud-restore path)', () async {
    await notifier.muteTerm('crypto');

    final fresh = SettingsNotifier(service);
    await fresh.loadSettings();
    expect(fresh.mutedTerms, equals(['crypto']));
  });
}
