import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/utils/constants.dart';
import 'package:curatedfeeds/utils/mute_filter.dart';

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

  group('SettingsService muted terms', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('empty by default', () async {
      final service = SettingsService();
      expect(await service.getMutedTerms(), isEmpty);
    });

    test('set normalizes: trim, lowercase, dedupe, cap', () async {
      final service = SettingsService();
      await service.setMutedTerms([
        '  Crypto ',
        'CRYPTO',
        'x' * 100,
        ...List.generate(60, (i) => 'term$i'),
      ]);

      final terms = await service.getMutedTerms();
      expect(terms, hasLength(maxMutedTerms));
      expect(terms.first, equals('crypto'));
      expect(terms.where((t) => t == 'crypto'), hasLength(1));
      expect(terms.every((t) => t.length <= maxMutedTermLength), isTrue);
    });

    test('set persists across instances', () async {
      final first = SettingsService();
      await first.setMutedTerms(['crypto', 'nfts']);

      final second = SettingsService();
      expect(await second.getMutedTerms(), equals(['crypto', 'nfts']));
    });

    test('muted_terms travels in the sync snapshot and restores', () async {
      final service = SettingsService();
      await service.setMutedTerms(['crypto', 'nfts']);

      final snapshot = await service.snapshotForSync();
      expect(snapshot['muted_terms'], equals(['crypto', 'nfts']));

      // A second install restores from the snapshot.
      SharedPreferences.setMockInitialValues({});
      final restored = SettingsService();
      await restored.restoreFromSync(snapshot);
      expect(await restored.getMutedTerms(), equals(['crypto', 'nfts']));
    });

    test('restore never accepts is_pro even beside muted_terms', () async {
      // Defence-in-depth companion to the M-1 test: adding a new synced
      // list key must not reopen the entitlement hole.
      final service = SettingsService();
      await service.restoreFromSync({
        'muted_terms': ['crypto'],
        'is_pro': true,
      });

      expect(await service.getMutedTerms(), equals(['crypto']));
      expect(await service.getIsPro(), isFalse);
    });
  });
}
