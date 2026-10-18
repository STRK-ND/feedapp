// Regression test: the feed screen's AppBar trailing actions overflowed on
// narrow viewports (rendered yellow/black stripes, clipped actions).
//
// AppBar renders `actions:` into a Row with mainAxisSize.min and no scroll,
// so its children never shrink. With an unread count the trailing row held
// "Mark all as read" (labelled), the count chip, refresh, search and the
// overflow menu; below ~500dp their combined width exceeded the bar.
// Measured before the fix: 192px over at 320dp, 152 at 360, 100 at 412,
// 32 at 480; clean from 600dp up.
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/l10n/generated/app_localizations.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/models/filter_params.dart';
import 'package:curatedfeeds/models/paginated_response.dart';
import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/screens/feed_screen.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/services/storage_service.dart';
import 'package:curatedfeeds/services/worker_feed_service.dart';
import 'package:firebase_analytics_platform_interface/firebase_analytics_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Platform-interface packages are transitive deps reached through their public
// package; tests need the interface types to install fakes.
// ignore_for_file: depend_on_referenced_packages

class _FakeConnectivityPlatform extends ConnectivityPlatform {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
}

class _FakeFirebasePlatform extends FirebasePlatform {
  static final FirebaseAppPlatform _app = FirebaseAppPlatform(
    defaultFirebaseAppName,
    const FirebaseOptions(
      apiKey: 'test',
      appId: 'test',
      messagingSenderId: 'test',
      projectId: 'test',
    ),
  );

  @override
  List<FirebaseAppPlatform> get apps => [_app];

  @override
  FirebaseAppPlatform app([String? name]) => _app;

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async => _app;
}

class _FakeAnalyticsPlatform extends FirebaseAnalyticsPlatform {
  @override
  FirebaseAnalyticsPlatform delegateFor({
    required FirebaseApp app,
    Map<String, dynamic>? webOptions,
  }) => this;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class _UnreadWorker extends WorkerFeedService {
  @override
  Future<PaginatedResponse> fetchArticles({FilterParams? params}) async {
    final articles = List.generate(
      30,
      (i) => Article(
        id: 'unread-$i',
        title: 'Unread headline number $i that still needs to be read',
        description: 'Body copy $i',
        fullContent: 'Content $i',
        link: 'https://example.com/a/$i',
        sourceId: 'src',
        sourceName: 'Source',
        pubDate: DateTime.now().subtract(Duration(minutes: i)),
      ),
    );
    return PaginatedResponse(
      items: articles,
      total: articles.length,
      page: 1,
      pageSize: 50,
      hasMore: false,
    );
  }
}

class _MemStorageService extends StorageService {
  @override
  Future<void> saveArticles(List<Article> articles) async {}

  @override
  Future<List<Article>> loadArticles() async =>
      List.generate(30, (i) => Article(
        id: 'unread-$i',
        title: 'Unread headline number $i',
        description: 'Body copy $i',
        fullContent: 'Content $i',
        link: 'https://example.com/a/$i',
        sourceId: 'src',
        sourceName: 'Source',
        pubDate: DateTime.now().subtract(Duration(minutes: i)),
      ));

  @override
  Future<void> saveSavedArticles(List<Article> articles) async {}

  @override
  Future<List<Article>> loadSavedArticles() async => const [];

  @override
  Future<void> saveLastRefreshTime(DateTime? time) async {}

  @override
  Future<DateTime?> loadLastRefreshTime() async => null;

  @override
  Future<void> saveArticle(Article article) async {}

  @override
  Future<void> upsertArticles(
    List<Article> articles, {
    Map<String, int>? clocks,
  }) async {}

  @override
  Future<void> saveSavedArticle(Article article) async {}

  @override
  Future<void> removeSavedArticle(String id) async {}

  @override
  Future<void> unsaveArticleLocally(String id) async {}

  @override
  Future<Map<String, int>> loadArticleTimestamps() async => const {};

  @override
  Future<void> clearFeedCache() async {}

  @override
  Future<void> clearAll() async {}
}

/// Widths where the trailing actions row previously overflowed, plus a
/// comfortable width that must keep working.
const _widths = <String, double>{
  '320': 320,
  '360': 360,
  '412': 412,
  '480': 480,
  '600': 600,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ConnectivityPlatform.instance = _FakeConnectivityPlatform();
    FirebasePlatform.instance = _FakeFirebasePlatform();
    FirebaseAnalyticsPlatform.instance = _FakeAnalyticsPlatform();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    getIt.reset();
  });

  _widths.forEach((label, width) {
    testWidgets('feed AppBar actions fit at ${label}dp', (tester) async {
      final errors = <String>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details.toString());
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);

      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() async => tester.binding.setSurfaceSize(null));

      final settings = SettingsService();
      final notifier = SettingsNotifier(settings);
      await notifier.setAutoRefresh(false);
      await notifier.setRefreshInterval(0);

      getIt.registerLazySingleton<SettingsService>(() => settings);
      getIt.registerLazySingleton<StorageService>(() => _MemStorageService());
      getIt.registerLazySingleton<ArticleRepository>(
        () => ArticleRepository(
          storageService: getIt<StorageService>(),
          workerFeedService: _UnreadWorker(),
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsNotifier>(
          create: (_) => notifier,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RssFeedScreen(),
          ),
        ),
      );
      // Fixed pumps, not pumpAndSettle: google_fonts can keep timers alive.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Prove the screen actually rendered the state that triggers the crowded
      // bar (articles present), so a vacuous pass is impossible.
      expect(
        find.byType(AppBar),
        findsOneWidget,
        reason: 'feed screen did not build an AppBar at ${label}dp',
      );

      expect(
        errors.where((e) => e.contains('A RenderFlex overflowed')),
        isEmpty,
        reason: 'feed screen overflowed its layout at ${label}dp',
      );
    });
  });
}
