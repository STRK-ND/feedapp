import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/utils/constants.dart';

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

    test('custom source ids survive the unknown-id filter', () async {
      final service = SettingsService();
      final customs = await service.addCustomSource(
        'My Blog',
        'https://blog.example/feed.xml',
      );
      final id = customs.single.id;

      // A subscribed set containing a custom id must not be pruned.
      await service.setSubscribedSourceIds({'verge', id});
      final ids = await service.getSubscribedSourceIds();
      expect(ids, equals({'verge', id}));
    });

    test('empty set round-trips as empty', () async {
      final service = SettingsService();
      await service.setSubscribedSourceIds({});
      final ids = await service.getSubscribedSourceIds();
      expect(ids, isEmpty);
    });
  });

  group('SettingsService notification categories', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to every category except All', () async {
      final service = SettingsService();
      final cats = await service.getNotificationCategories();
      expect(cats, isNot(contains('All')));
      expect(cats.length, AppConfig.categories.length - 1);
    });

    test('full selection normalizes to unrestricted empty list', () async {
      final service = SettingsService();
      await service.setNotificationCategories(
        AppConfig.categories.where((c) => c != 'All').toList(),
      );
      // Stored as [] = "no restriction"; reads back as all categories.
      final cats = await service.getNotificationCategories();
      expect(cats, isNot(contains('All')));
      expect(cats.length, AppConfig.categories.length - 1);
    });

    test('subset round-trips; invalid names are dropped', () async {
      final service = SettingsService();
      await service.setNotificationCategories(['Tech', 'BogusCat']);
      expect(await service.getNotificationCategories(), ['Tech']);
    });

    test('empty selection falls back to all categories', () async {
      final service = SettingsService();
      await service.setNotificationCategories([]);
      expect(
        await service.getNotificationCategories(),
        AppConfig.categories.where((c) => c != 'All').toList(),
      );
    });
  });

  group('SettingsService custom sources', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('add persists and derives host as name when name empty', () async {
      final service = SettingsService();
      final customs = await service.addCustomSource(
        '',
        'https://feeds.example.com/rss.xml',
      );

      expect(customs.length, 1);
      expect(customs.single.name, 'feeds.example.com');
      expect(customs.single.url, 'https://feeds.example.com/rss.xml');
      expect(customs.single.id, startsWith('custom-'));
    });

    test('adding the same URL twice is a no-op', () async {
      final service = SettingsService();
      await service.addCustomSource('A', 'https://x.example/feed');
      final again = await service.addCustomSource(
        'B',
        'https://X.example/feed',
      );
      expect(again.length, 1);
    });

    test('remove deletes the source and unsubscribes it', () async {
      final service = SettingsService();
      final customs = await service.addCustomSource(
        'Rm',
        'https://r.example/f',
      );
      final id = customs.single.id;
      await service.setSubscribedSourceIds({'verge', id});

      await service.removeCustomSource(id);

      expect(await service.getCustomSources(), isEmpty);
      expect(await service.getSubscribedSourceIds(), {'verge'});
    });
  });
}
