// Platform-interface packages (connectivity, firebase_core,
// firebase_analytics) are only transitive deps — the app talks to them
// through connectivity_plus / firebase_core / firebase_analytics. Tests
// need the interface types to install fakes, so the direct imports are
// intentional.
// ignore_for_file: depend_on_referenced_packages

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:curatedfeeds/di/service_locator.dart';
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

/// FeedScreen's empty/error states, pumped for real.
///
/// The screen pulls its services straight out of `getIt`, so the test
/// registers the same service graph the app uses and drives refresh
/// results by swapping the WorkerFeedService. Platform singletons
/// (connectivity, firebase) are replaced with fakes so no channel
/// traffic or timers leak into the fake-async zone.

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

/// Worker that returns no articles — refresh "succeeds" with an empty feed.
class _EmptyWorker extends WorkerFeedService {
  @override
  Future<PaginatedResponse> fetchArticles({FilterParams? params}) async {
    return PaginatedResponse(
      items: const [],
      total: 0,
      page: 1,
      pageSize: 50,
      hasMore: false,
    );
  }
}

/// Worker that throws — refresh fails and the error state should surface.
class _ThrowingWorker extends WorkerFeedService {
  @override
  Future<PaginatedResponse> fetchArticles({FilterParams? params}) async {
    throw Exception('Server error');
  }
}

Future<void> _pumpFeed(
  WidgetTester tester, {
  required WorkerFeedService worker,
}) async {
  final settings = SettingsService();
  final notifier = SettingsNotifier(settings);
  // Disable auto-refresh so no 30-minute Timer is left pending at test
  // end (flutter_test fails on leftover timers).
  await notifier.setAutoRefresh(false);
  await notifier.setRefreshInterval(0);

  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<SettingsService>(() => settings);
  getIt.registerLazySingleton<ArticleRepository>(
    () => ArticleRepository(
      storageService: getIt<StorageService>(),
      workerFeedService: worker,
    ),
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsNotifier>(
      create: (_) => notifier,
      child: const MaterialApp(home: RssFeedScreen()),
    ),
  );

  // Fixed pumps, not pumpAndSettle: google_fonts can keep timers alive.
  // Enough steps for init → storage load → refresh → settle.
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
    // Keep google_fonts off the network in the fake-async zone.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    getIt.reset();
  });

  testWidgets(
    'empty state: no articles in storage renders "The day is quiet."',
    (tester) async {
      await _pumpFeed(tester, worker: _EmptyWorker());

      expect(find.text('The day is quiet.'), findsOneWidget);
      expect(
        find.text('Tap the refresh button to load articles'),
        findsOneWidget,
      );
      expect(find.byType(RefreshIndicator), findsOneWidget);
    },
  );

  testWidgets('error state: refresh failure renders error + Retry button', (
    tester,
  ) async {
    await _pumpFeed(tester, worker: _ThrowingWorker());

    expect(find.text('Server error. Please try again later.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });
}
