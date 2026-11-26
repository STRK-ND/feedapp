// Cold-launch local-read regression.
//
// The feed screen used to read the local cache straight out of
// StorageService even though ArticleRepository — the owner of the
// validated in-memory set — had just validated the same rows during the
// splash preload. One app cold launch therefore read and JSON-decoded the
// whole `articles` and `saved_articles` tables twice, in two identical
// passes, for identical results.
//
// The invariant pinned here is the one the fix relies on: the screen
// sources its local feed through the repository, so a cold launch spends
// exactly one full read of each table no matter how many load triggers
// fire on the same process snapshot. It is a consumer-visible quantity —
// the second pass was pure CPU and I/O on the main path to first paint.

// ignore_for_file: depend_on_referenced_packages

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:curatedfeeds/di/service_locator.dart';
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
import 'package:curatedfeeds/l10n/generated/app_localizations.dart';
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

/// Returns nothing: refresh succeeds with an empty page so the measured
/// launch path stays local.
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

/// Counts full-table reads. In-memory because sqflite ffi cannot run
/// inside a testWidgets fake-async zone.
class _CountingStorageService extends StorageService {
  _CountingStorageService(this._articles, this._saved);

  final List<Article> _articles;
  final List<Article> _saved;
  int articleReads = 0;
  int savedReads = 0;

  @override
  Future<void> saveArticles(List<Article> articles) async {
    _articles
      ..clear()
      ..addAll(articles);
  }

  @override
  Future<List<Article>> loadArticles() async {
    articleReads++;
    return List.of(_articles);
  }

  @override
  Future<int> countArticles() async => _articles.length;

  @override
  Future<void> saveSavedArticles(List<Article> articles) async {
    _saved
      ..clear()
      ..addAll(articles);
  }

  @override
  Future<List<Article>> loadSavedArticles() async {
    savedReads++;
    return List.of(_saved);
  }

  @override
  Future<int> countSavedArticles() async => _saved.length;

  @override
  Future<void> saveLastRefreshTime(DateTime? time) async {}

  @override
  Future<DateTime?> loadLastRefreshTime() async => null;
}

/// Refresh returns an empty page so the launch path stays local.
final WorkerFeedService worker = _EmptyWorker();

List<Article> _articles() {
  final now = DateTime.now().millisecondsSinceEpoch;
  // Canonical registry ids — getSubscribedSourceIds() defaults to the
  // whole registry on first run, and _getFilteredArticles() drops
  // anything outside it.
  const ids = ['verge', 'wired', 'bbc', 'guardian'];
  return [
    for (var i = 0; i < 30; i++)
      Article(
        id: 'a$i',
        title: 'Headline $i',
        description: 'Body $i',
        fullContent: 'Content $i',
        link: 'https://example.com/$i',
        sourceId: ids[i % ids.length],
        sourceName: 'Source',
        pubDate: DateTime.fromMillisecondsSinceEpoch(now - i * 60000),
        // Coprime with the 4-source cycle so every source keeps both
        // read and unread entries — a filter test needs each side.
        isRead: i % 5 == 0,
      ),
  ];
}

Future<void> _pumpFeed(
  WidgetTester tester, {
  required _CountingStorageService storage,
  required ArticleRepository repository,
  List<String> mutedTerms = const [],
  bool showSaved = false,
}) async {
  final settings = SettingsService();
  final notifier = SettingsNotifier(settings);
  await notifier.setAutoRefresh(false);
  await notifier.setRefreshInterval(0);
  if (mutedTerms.isNotEmpty) {
    await notifier.setMutedTerms(mutedTerms);
  }

  getIt.registerLazySingleton<SettingsService>(() => settings);
  getIt.registerLazySingleton<StorageService>(() => storage);
  getIt.registerLazySingleton<WorkerFeedService>(() => worker);
  getIt.registerLazySingleton<ArticleRepository>(() => repository);

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsNotifier>(
      create: (_) => notifier,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: showSaved
            ? const RssFeedScreen(showSavedArticles: true)
            : const RssFeedScreen(),
      ),
    ),
  );

  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
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

  testWidgets(
    'cold launch reads each local table once, not once per load trigger',
    (tester) async {
      final storage = _CountingStorageService(_articles(), <Article>[]);

      // The splash preload validates the same rows the screen is about to
      // ask for — this is the state every real cold launch is in. The
      // screen resolves its repository through getIt, so this MUST be the
      // same instance the screen will get.
      final repo = ArticleRepository(
        storageService: storage,
        workerFeedService: worker,
      );
      await repo.fetchSavedArticles();
      await repo.fetchAllArticles();
      final afterPreload = (storage.articleReads, storage.savedReads);
      expect(afterPreload, (1, 1), reason: 'preload itself reads once');

      await _pumpFeed(tester, storage: storage, repository: repo);

      // The screen consumed the validated snapshot instead of re-reading.
      expect(
        storage.articleReads,
        1,
        reason: 'the feed screen must not re-read the article table',
      );
      expect(
        storage.savedReads,
        1,
        reason: 'the feed screen must not re-read the saved table',
      );
    },
  );

  testWidgets('the cached feed still renders after the change', (tester) async {
    final storage = _CountingStorageService(_articles(), <Article>[]);
    final repo = ArticleRepository(
      storageService: storage,
      workerFeedService: worker,
    );
    await repo.fetchAllArticles();
    await repo.fetchSavedArticles();

    await _pumpFeed(tester, storage: storage, repository: repo);

    // The stack renders the front card only, and the front card is the
    // first unread/unsaved entry — the shared filter, not the raw list.
    expect(find.text('Headline 1'), findsOneWidget);
    expect(find.text('Headline 0'), findsNothing, reason: 'isRead excluded');
  });

  testWidgets('a source-filtered launch shows only subscribed sources', (
    tester,
  ) async {
    final storage = _CountingStorageService(_articles(), <Article>[]);
    final repo = ArticleRepository(
      storageService: storage,
      workerFeedService: worker,
    );
    await repo.fetchAllArticles();
    await repo.fetchSavedArticles();

    // Subscribe to one source: the unread, unsaved entry whose source is
    // 'bbc' must become the front card.
    final settings = SettingsService();
    await settings.init();
    await settings.setSubscribedSourceIds({'bbc'});

    await _pumpFeed(tester, storage: storage, repository: repo);

    // Headline 2 is the first unread entry from 'bbc' (ids cycle every
    // 4, so a2 → ids[2] = 'bbc').
    expect(find.text('Headline 2'), findsOneWidget);
    expect(find.text('Headline 1'), findsNothing, reason: 'wired is filtered');
  });

  testWidgets('a forced saved refresh re-reads storage and revalidates the '
      'repository snapshot', (tester) async {
    final storage = _CountingStorageService(_articles(), <Article>[]);
    final repo = ArticleRepository(
      storageService: storage,
      workerFeedService: worker,
    );
    await repo.fetchAllArticles();
    await repo.fetchSavedArticles();
    expect(storage.savedReads, 1, reason: 'preload reads once');

    await _pumpFeed(tester, storage: storage, repository: repo);
    expect(storage.savedReads, 1, reason: 'launch reused the snapshot');

    // The gesture is explicit user intent to re-read storage, so the
    // saved-articles refresh must NOT be served from the snapshot: the
    // repository has to revalidate against disk, or the Saved tab keeps
    // showing rows deleted from storage by another device.
    await repo.fetchSavedArticles(forceRefresh: true);

    expect(storage.savedReads, 2);
  });

  testWidgets('muted keywords hide matching articles from the feed tab', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    Article article(String id, String title, String description) => Article(
      id: id,
      title: title,
      description: description,
      fullContent: '',
      link: 'https://example.com/$id',
      sourceId: 'verge',
      sourceName: 'Source',
      pubDate: DateTime.fromMillisecondsSinceEpoch(now),
    );
    final storage = _CountingStorageService(
      [
        article('m1', 'Quantum rally', 'markets'),
        article('ok1', 'Plain headline', 'nothing special'),
      ],
      <Article>[],
    );
    final repo = ArticleRepository(
      storageService: storage,
      workerFeedService: worker,
    );
    await repo.fetchAllArticles();
    await repo.fetchSavedArticles();

    await _pumpFeed(
      tester,
      storage: storage,
      repository: repo,
      mutedTerms: ['quantum'],
    );

    // The muted article is gone from the visible list entirely; the
    // unmuted one is the front card of the stack.
    expect(find.text('Quantum rally'), findsNothing);
    expect(find.text('Plain headline'), findsOneWidget);
  });

  testWidgets('the saved tab is never muted-filtered', (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final saved = Article(
      id: 's1',
      title: 'Quantum rally',
      description: 'markets',
      fullContent: '',
      link: 'https://example.com/s1',
      sourceId: 'verge',
      sourceName: 'Source',
      pubDate: DateTime.fromMillisecondsSinceEpoch(now),
      isSaved: true,
    );
    final storage = _CountingStorageService(
      <Article>[],
      [saved],
    );
    final repo = ArticleRepository(
      storageService: storage,
      workerFeedService: worker,
    );
    await repo.fetchAllArticles();
    await repo.fetchSavedArticles();

    await _pumpFeed(
      tester,
      storage: storage,
      repository: repo,
      mutedTerms: ['quantum'],
      showSaved: true,
    );

    // Saving was a deliberate act — the same muted term that hides the
    // article from the feed must not hide it from Saved.
    expect(find.text('Quantum rally'), findsOneWidget);
  });
}
