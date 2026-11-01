// Regression test: interactive rows in Settings painted no touch feedback.
//
// `_buildSettingsCard` groups tiles inside a Container with a background color,
// so every interactive ListTile sat under a DecoratedBox whose alpha is
// nonzero. ListTile paints its background and ink splashes on the nearest
// Material ancestor — which is above that DecoratedBox — so the card's
// translucent fill covered the splash. The row responded to the tap but the
// user saw nothing. Flutter reports this as "ListTile background color or ink
// splashes may be invisible"; the user-visible defect is a dead-feeling row.
//
// The invariant asserted here is the one that decides visibility: between an
// interactive ListTile and the Material that hosts its ink there must be no
// background-painted ColoredBox/DecoratedBox. This replicates
// ListTile._findIntermediateWidget deliberately, because that is the exact
// condition under which the splash the user should see is painted over.
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/l10n/generated/app_localizations.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/models/paginated_response.dart';
import 'package:curatedfeeds/models/filter_params.dart';
import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/screens/settings_screen.dart';
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

class _Worker extends WorkerFeedService {
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
  @override
  Future<void> saveArticles(List<Article> articles) async {}
  @override
  Future<List<Article>> loadArticles() async => const [];
  @override
  Future<int> countArticles() async => 0;
  @override
  Future<void> saveSavedArticles(List<Article> articles) async {}
  @override
  Future<List<Article>> loadSavedArticles() async => const [];
  @override
  Future<int> countSavedArticles() async => 0;
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

  /// Pumps the real Settings screen with the app's own service graph.
  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final settings = SettingsService();
    final notifier = SettingsNotifier(settings);
    getIt.registerLazySingleton<SettingsService>(() => settings);
    getIt.registerLazySingleton<StorageService>(() => _MemStorageService());
    getIt.registerLazySingleton<ArticleRepository>(
      () => ArticleRepository(
        storageService: getIt<StorageService>(),
        workerFeedService: _Worker(),
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsNotifier>(
        create: (_) => notifier,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('every interactive Settings row shows its tap feedback', (
    tester,
  ) async {
    await pumpSettings(tester);

    // The screen body is a lazy ListView, so a row only exists while its
    // section is on screen. Collect every distinct offending row across the
    // whole scroll journey, down and back up.
    final offenders = <String>{};
    void collect() {
      for (final element in find.byType(ListTile).evaluate()) {
        final tile = element.widget as ListTile;
        if (tile.onTap == null) continue;
        final hiddenBy = _opaqueBackgroundBetweenTileAndInk(element);
        if (hiddenBy == null) continue;
        final title = find
            .descendant(of: find.byWidget(tile), matching: find.byType(Text))
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .firstWhere((s) => s.isNotEmpty, orElse: () => '?');
        offenders.add('$title via $hiddenBy');
      }
    }

    collect();
    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 30));
      collect();
    }
    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await tester.pump(const Duration(milliseconds: 30));
      collect();
    }
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      offenders,
      isEmpty,
      reason:
          'these Settings rows are interactive but their ink splash is painted '
          'on a Material that sits below a background ColoredBox/DecoratedBox, '
          'so the tap gives the user no visible feedback',
    );
  });
}

/// The first background-painted ColoredBox/DecoratedBox between [tile] and the
/// Material that hosts its ink, or null when the tile's splash is unobstructed.
///
/// Mirrors `ListTile._findIntermediateWidget` on purpose: this is the exact
/// condition under which the framework reports the splash may be invisible.
String? _opaqueBackgroundBetweenTileAndInk(Element tile) {
  String? culprit;
  tile.visitAncestorElements((ancestor) {
    if (ancestor.widget is Material) return false;
    final color = switch (ancestor.widget) {
      ColoredBox(:final Color color) => color,
      DecoratedBox(decoration: BoxDecoration(:final Color? color)) => color,
      DecoratedBox(decoration: ShapeDecoration(:final Color? color)) => color,
      _ => null,
    };
    if (color != null && color.a > 0) {
      culprit = ancestor.widget.runtimeType.toString();
      return false;
    }
    return true;
  });
  return culprit;
}
