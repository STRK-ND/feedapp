import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:curatedfeeds/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsService subscriptions', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns all canonical IDs on first run', () async {
      final service = SettingsService();
      final ids = await service.getSubscribedSourceIds();
      expect(ids, equals(canonicalSourceIds()));
    });

    test('set persists across instances', () async {
      final first = SettingsService();
      await first.setSubscribedSourceIds({'verge', 'bbc'});

      final second = SettingsService();
      final ids = await second.getSubscribedSourceIds();
      expect(ids, equals({'verge', 'bbc'}));
    });

    test('unknown ids are filtered out on read', () async {
      final service = SettingsService();
      await service.setSubscribedSourceIds({'verge', 'bogus-source', 'bbc'});
      final ids = await service.getSubscribedSourceIds();
      expect(ids, equals({'verge', 'bbc'}));
    });

    test('empty set round-trips as empty', () async {
      final service = SettingsService();
      await service.setSubscribedSourceIds({});
      final ids = await service.getSubscribedSourceIds();
      expect(ids, isEmpty);
    });
  });
}
