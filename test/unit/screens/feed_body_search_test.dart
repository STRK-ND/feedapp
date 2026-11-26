// Body search (FTS5) Pro gate: free users see the match count with a
// locked teaser routing to the paywall; Pro users get the hits merged
// underneath the title hits. The repository is faked at searchBodies —
// sqlite (ffi) cannot run inside a testWidgets fake-async zone.
// ignore_for_file: depend_on_referenced_packages

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/l10n/generated/app_localizations.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/models/filter_params.dart';
import 'package:curatedfeeds/models/paginated_response.dart';
import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/screens/feed_screen.dart';
import 'package:curatedfeeds/services/feed_database.dart';
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
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) => _app;

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

class _EmptyWorker extends WorkerFeedService {
  @override
  Future<PaginatedResponse> fetchArticles({FilterParams? params}) async =>
      PaginatedResponse(
        items: const [],
        total: 0,
        page: 1,
        pageSize: 50,
        hasMore: false,
      );
}

class _MemStorageService extends StorageService {
  final List<Article> _articles = [];
  final List<Article> _saved = [];

  _MemStorageService(List<Article> articles) {
    _articles.addAll(articles);
  }

  @override
  Future<void> saveArticles(List<Article> articles) async {
    _articles
      ..clear()
      ..addAll(articles);
  }

  @override
  Future<List<Article>> loadArticles() async => List.of(_articles);

  @override
  Future<int> countArticles() async => _articles.length;

  @override
  Future<void> saveSavedArticles(List<Article> articles) async {
    _saved
      ..clear()
      ..addAll(articles);
  }

  @override
  Future<List<Article>> loadSavedArticles() async => List.of(_saved);

  @override
  Future<int> countSavedArticles() async => _saved.length;
}

/// Repository double whose body search returns canned hits regardless of
/// the query — the screen's Pro gate is what's under test, not FTS.
class _CannedSearchRepository extends ArticleRepository {
  _CannedSearchRepository({
    required super.storageService,
    required super.workerFeedService,
  });

  List<BodySearchHit>? hits = [];

  @override
  Future<List<BodySearchHit>?> searchBodies(
    String query, {
    bool savedOnly = false,
  }) async => hits;
}

Article _article(String id, String title) => Article(
  id: id,
  title: title,
  description: 'Body text for $id',
  fullContent: '',
  link: 'https://example.com/$id',
  sourceId: 'verge',
  sourceName: 'Source',
  pubDate: DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch,
  ),
);

Future<void> _pumpFeed(
  WidgetTester tester, {
  required ArticleRepository repository,
  required StorageService storage,
  required SettingsNotifier notifier,
}) async {
  getIt.registerLazySingleton<SettingsService>(() => SettingsService());
  getIt.registerLazySingleton<StorageService>(() => storage);
  getIt.registerLazySingleton<ArticleRepository>(() => repository);

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

  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Open search and submit [query] (past the 250 ms debounce).
Future<void> _search(WidgetTester tester, String query) async {
  await tester.tap(find.byIcon(Icons.search_rounded).first);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.enterText(find.byType(TextField).first, query);
  // Fire the 250 ms debounce timer, then let the async body search land.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 50));
}

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

  testWidgets('free user: body matches show as a locked teaser, not results', (
    tester,
  ) async {
    final articles = [_article('a1', 'Plain headline one')];
    final storage = _MemStorageService(articles);
    final repo = _CannedSearchRepository(
      storageService: storage,
      workerFeedService: _EmptyWorker(),
    )..hits = [const BodySearchHit(id: 'a1', snippet: '…zebra…')];
    final notifier = SettingsNotifier(SettingsService());
    await notifier.setAutoRefresh(false);
    await notifier.setRefreshInterval(0);

    await _pumpFeed(
      tester,
      repository: repo,
      storage: storage,
      notifier: notifier,
    );
    await _search(tester, 'zebra');

    // The count is free; the results are not.
    expect(find.text('1 match in article bodies'), findsOneWidget);
    expect(find.text('Go Pro to open these results'), findsOneWidget);
    // The matched article is NOT rendered.
    expect(find.text('Plain headline one'), findsNothing);
  });

  testWidgets('Pro user: body hits merge underneath the title hits', (
    tester,
  ) async {
    final articles = [
      _article('a1', 'Plain headline one'),
      _article('a2', 'Zebra plains headline'),
    ];
    final storage = _MemStorageService(articles);
    final repo = _CannedSearchRepository(
      storageService: storage,
      workerFeedService: _EmptyWorker(),
    )..hits = [const BodySearchHit(id: 'a1', snippet: '…zebra…')];
    final notifier = SettingsNotifier(SettingsService());
    await notifier.setAutoRefresh(false);
    await notifier.setRefreshInterval(0);
    await notifier.setIsPro(true);

    await _pumpFeed(
      tester,
      repository: repo,
      storage: storage,
      notifier: notifier,
    );
    await _search(tester, 'zebra');

    // Title hit first (a2 matches by title), body hit underneath (a1).
    expect(find.text('Zebra plains headline'), findsOneWidget);
    expect(find.text('Plain headline one'), findsOneWidget);
    expect(find.text('Also matching inside article bodies'), findsOneWidget);
    // No locked teaser for Pro users.
    expect(find.text('Go Pro to open these results'), findsNothing);
  });

  testWidgets('free user with no body matches: plain empty state', (
    tester,
  ) async {
    final articles = [_article('a1', 'Plain headline one')];
    final storage = _MemStorageService(articles);
    final repo = _CannedSearchRepository(
      storageService: storage,
      workerFeedService: _EmptyWorker(),
    )..hits = const [];
    final notifier = SettingsNotifier(SettingsService());
    await notifier.setAutoRefresh(false);
    await notifier.setRefreshInterval(0);

    await _pumpFeed(
      tester,
      repository: repo,
      storage: storage,
      notifier: notifier,
    );
    await _search(tester, 'zebra');

    expect(find.text('No results for "zebra"'), findsOneWidget);
    expect(find.text('Go Pro to open these results'), findsNothing);
  });
}
