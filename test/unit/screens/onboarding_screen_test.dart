import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/l10n/generated/app_localizations.dart';
import 'package:curatedfeeds/screens/onboarding_screen.dart';
import 'package:curatedfeeds/services/rss_feed_service.dart';
import 'package:curatedfeeds/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerLazySingleton<SettingsService>(() => SettingsService());
    // Step 3 renders picks from the source registry (bundled seed offline).
    getIt.registerLazySingleton<RssFeedService>(() => RssFeedService());
  });

  tearDown(() async {
    await getIt.reset();
  });

  // Tall viewport so all three onboarding steps (which are single-child
  // scroll views) render fully without needing scroll gestures.
  void useTallViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // Tap Continue until the 240ms page animation completes, so
  // PageView.onPageChanged fires and _step advances.
  Future<void> advanceStep(WidgetTester tester) async {
    await tester.tap(find.text('CONTINUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  // Tap a custom tap-target (Semantics -> GestureDetector -> card) by its text
  // label. Targeting the raw text can miss — hit the whole card instead.
  Future<void> tapCard(WidgetTester tester, String label) async {
    await tester.tap(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(GestureDetector),
      ),
    );
    await tester.pump();
  }

  testWidgets('picking a source and finishing persists subscription and '
      'theme/font prefs', (tester) async {
    useTallViewport(tester);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(),
      ),
    );

    // Step 1 — pick a room so the theme pref is non-default.
    await tapCard(tester, 'LAMPLIGHT');

    // Step 2 — toggle typewriter datelines off (a reader pref write).
    await advanceStep(tester);
    await tester.tap(find.text('TYPEWRITER DATELINES'));
    await tester.pump();

    // Step 3 — pick The Verge; the check indicator appears.
    await advanceStep(tester);
    expect(find.text('PICK A FIRST SOURCE'), findsOneWidget);
    await tapCard(tester, 'The Verge');
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Finish. Prefs are written inside _finish() BEFORE navigation, so a
    // single pump is enough for them to land.
    await tester.tap(find.textContaining('CONTINUE'));
    await tester.pump();

    // The push to CuratedFeedsApp builds RssFeedScreen, whose State field
    // initializers call getIt<StorageService>()/getIt<ArticleRepository>().
    // Those are intentionally not registered here (only SettingsService is,
    // which OnboardingScreen needs), so the route build throws a single
    // StateError in the test environment. That is expected — the prefs are
    // already persisted — so swallow the captured exception.
    // Note: we avoid pumpAndSettle here because google_fonts runtime font
    // loading can add network timers that make it flaky.
    tester.takeException();

    final settings = SettingsService();
    final subscribed = await settings.getSubscribedSourceIds();
    expect(subscribed, contains('verge'));
    expect(await settings.getThemeMode(), ThemeMode.dark);
    expect(await settings.getMonoDatelinesEnabled(), isFalse);
    expect(await settings.getReaderFontSize(), 16.0);
    expect(await settings.getReaderLineHeight(), 1.6);
    expect(await settings.getHasCompletedOnboarding(), isTrue);
  });

  testWidgets('CONTINUE WITHOUT keeps the all-sources default subscription', (
    tester,
  ) async {
    useTallViewport(tester);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingScreen(),
      ),
    );

    await advanceStep(tester); // step 1 -> 2
    await advanceStep(tester); // step 2 -> 3
    expect(find.text('PICK A FIRST SOURCE'), findsOneWidget);

    // No source picked; button reads CONTINUE WITHOUT.
    await tester.tap(find.text('CONTINUE WITHOUT'));
    await tester.pump();

    // Same route-build swallow as the first test.
    tester.takeException();

    // _pickedSources is empty, so _finish() never writes the
    // subscribed_source_ids pref — the all-sources default remains.
    final settings = SettingsService();
    final subscribed = await settings.getSubscribedSourceIds();
    expect(subscribed, equals(canonicalSourceIds()));
    expect(await settings.getHasCompletedOnboarding(), isTrue);
  });
}
