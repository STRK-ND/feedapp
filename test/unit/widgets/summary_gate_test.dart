// AI summaries on the reader card: the free-tier trial gate routes past
// its allowance to the paywall without spending a request; Pro users get
// the summary rendered and their trial counter untouched.
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/l10n/generated/app_localizations.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/screens/paywall_screen.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/services/storage_service.dart';
import 'package:curatedfeeds/services/summarize_service.dart';
import 'package:curatedfeeds/widgets/expanded_article_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// Platform-interface import needed for the fake; transitive dependency.
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeIAP extends InAppPurchasePlatform {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: [],
      notFoundIDs: identifiers.toList(),
    );
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}
}

/// StorageService double: no disk I/O (sqlite ffi cannot run inside a
/// testWidgets fake-async zone); the summary cache reads as empty.
class _NoStorageService extends StorageService {
  @override
  Future<String?> getSummary(String articleId) async => null;

  @override
  Future<void> saveSummary(String articleId, String text) async {}
}

Article _article() => Article(
  id: 'a1',
  title: 'Test Article Title',
  description: 'A' * 400,
  fullContent: '',
  link: 'https://example.com/1',
  sourceId: 'verge',
  sourceName: 'The Verge',
  pubDate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

Future<void> _pumpCard(
  WidgetTester tester,
  Article article, {
  SettingsNotifier? notifier,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsNotifier>(
      create: (_) => notifier ?? SettingsNotifier(SettingsService()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExpandedArticleCard(
            article: article,
            onClose: () {},
            onToggleSave: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUpAll(() {
    // The paywall reads the store; the fake answers "unavailable".
    InAppPurchasePlatform.instance = _FakeIAP();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    requests = [];
  });

  testWidgets('free user past the trial: paywall, no request spent', (
    tester,
  ) async {
    final ym = SummarizeService.currentYm(DateTime.now().toUtc());
    SharedPreferences.setMockInitialValues({
      'summary_free_ym': ym,
      'summary_free_used': kFreeTrialMonthlySummaries,
    });
    getIt.registerSingleton<StorageService>(_NoStorageService());
    final notifier = SettingsNotifier(SettingsService());
    await notifier.setAutoRefresh(false);
    await notifier.setRefreshInterval(0);
    getIt.registerSingleton<SummarizeService>(
      SummarizeService(
        httpClient: MockClient((r) async {
          requests.add(r);
          return http.Response('{"summary":"s"}', 200);
        }),
        idTokenProvider: () async => 'id-token',
      ),
    );

    await _pumpCard(tester, _article(), notifier: notifier);
    await tester.tap(find.text('Summarize with AI'));
    // Fixed pumps: the paywall runs continuous animations, so
    // pumpAndSettle would time out.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Routed to the paywall (R-1 pattern) and nothing was requested.
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('Pro user: summary renders, trial counter untouched', (
    tester,
  ) async {
    final service = SummarizeService(
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response('{"summary":"- one\\n- two\\n- three"}', 200);
      }),
      idTokenProvider: () async => 'id-token',
    );
    getIt.registerSingleton<StorageService>(_NoStorageService());
    getIt.registerSingleton<SummarizeService>(service);
    final settings = SettingsService();
    final notifier = SettingsNotifier(settings);
    await notifier.setIsPro(true);

    await _pumpCard(tester, _article(), notifier: notifier);
    await tester.tap(find.text('Summarize with AI'));
    await tester.pumpAndSettle();

    expect(find.text('AI SUMMARY'), findsOneWidget);
    expect(find.text('- one\n- two\n- three'), findsOneWidget);
    expect(requests, hasLength(1));
    // Pro usage never consumes the free-trial counter.
    expect(await service.remainingFreeTrial(), kFreeTrialMonthlySummaries);
  });

  testWidgets('free user inside the trial: summary renders and counter ticks', (
    tester,
  ) async {
    final service = SummarizeService(
      httpClient: MockClient((r) async {
        requests.add(r);
        return http.Response('{"summary":"- one"}', 200);
      }),
      idTokenProvider: () async => 'id-token',
    );
    getIt.registerSingleton<StorageService>(_NoStorageService());
    getIt.registerSingleton<SummarizeService>(service);

    await _pumpCard(tester, _article());
    await tester.tap(find.text('Summarize with AI'));
    await tester.pumpAndSettle();

    expect(find.text('AI SUMMARY'), findsOneWidget);
    expect(requests, hasLength(1));
    expect(await service.remainingFreeTrial(), kFreeTrialMonthlySummaries - 1);
  });
}
