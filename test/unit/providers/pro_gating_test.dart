import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/utils/reader_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isReaderThemeLocked', () {
    test('free user cannot use sepia or eInk', () {
      expect(isReaderThemeLocked(ReaderTheme.sepia, false), isTrue);
      expect(isReaderThemeLocked(ReaderTheme.eInk, false), isTrue);
    });

    test('free user can use default and paper', () {
      expect(isReaderThemeLocked(ReaderTheme.defaultTheme, false), isFalse);
      expect(isReaderThemeLocked(ReaderTheme.paper, false), isFalse);
    });

    test('pro user can use everything', () {
      for (final t in ReaderTheme.values) {
        expect(isReaderThemeLocked(t, true), isFalse, reason: '$t');
      }
    });
  });

  group('SettingsNotifier.isPro', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to false on fresh install', () async {
      final notifier = SettingsNotifier(SettingsService());
      await notifier.loadSettings();
      expect(notifier.isPro, isFalse);
    });

    test('setIsPro(true) flips flag and notifies listeners', () async {
      final notifier = SettingsNotifier(SettingsService());
      await notifier.loadSettings();

      var notified = 0;
      notifier.addListener(() => notified++);

      await notifier.setIsPro(true);
      expect(notifier.isPro, isTrue);
      expect(notified, greaterThan(0));
    });

    test('setIsPro persists across instances', () async {
      final first = SettingsNotifier(SettingsService());
      await first.loadSettings();
      await first.setIsPro(true);

      final second = SettingsNotifier(SettingsService());
      await second.loadSettings();
      expect(second.isPro, isTrue);
    });
  });
}
