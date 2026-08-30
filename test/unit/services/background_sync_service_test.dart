import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/utils/error_handler.dart';
import 'package:curatedfeeds/services/background_sync_service.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/services/storage_service.dart';

/// Repository stub whose refresh outcome is controlled per-test.
class _StubRepository extends ArticleRepository {
  _StubRepository({required this.outcome});

  final Result<List<Article>> outcome;
  int callCount = 0;

  @override
  Future<Result<List<Article>>> fetchNewArticles() async {
    callCount++;
    return outcome;
  }
}

Article _article(String id) => Article(
      id: id,
      title: id,
      description: '',
      fullContent: '',
      link: 'https://example.com/$id',
      sourceId: 'verge',
      sourceName: 'The Verge',
      pubDate: DateTime.utc(2026, 1, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsService settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await setupServiceLocator();
    settings = SettingsService();
    await settings.init();
  });

  group('runBackgroundSync', () {
    test('skips the fetch when autoRefresh is off', () async {
      await settings.setAutoRefresh(false);
      final repo = _StubRepository(
        outcome: Result.success(<Article>[_article('a')]),
      );

      final cached = await runBackgroundSync(repository: repo, settings: settings);

      expect(cached, 0);
      expect(repo.callCount, 0);
    });

    test('refreshes and stamps lastRefreshTime when enabled', () async {
      await settings.setAutoRefresh(true);
      final storage = getIt<StorageService>();
      final repo = _StubRepository(
        outcome: Result.success(<Article>[_article('a'), _article('b')]),
      );

      final cached = await runBackgroundSync(
        repository: repo,
        settings: settings,
        storage: storage,
      );

      expect(cached, 2);
      expect(repo.callCount, 1);
      expect(await storage.loadLastRefreshTime(), isNotNull);
    });

    test('rethrows on failure so WorkManager retries', () async {
      await settings.setAutoRefresh(true);
      final repo = _StubRepository(outcome: Result.failure('Server error'));

      await expectLater(
        runBackgroundSync(repository: repo, settings: settings),
        throwsException,
      );
    });
  });

  group('scheduleBackgroundSync', () {
    test('completes without throwing when the platform channel is absent',
        () async {
      // Unit tests have no WorkManager channel; the service must swallow
      // that and never break launch or the Settings toggle.
      await settings.setAutoRefresh(false);
      await scheduleBackgroundSync(settings);

      await settings.setAutoRefresh(true);
      await scheduleBackgroundSync(settings);
    });
  });
}
