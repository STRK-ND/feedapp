import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/l10n/generated/app_localizations.dart';
import 'package:curatedfeeds/services/update_service.dart';
import 'package:curatedfeeds/widgets/update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  UpdateInfo sampleInfo() => UpdateInfo(
    version: '1.2.2',
    releaseDate: '2026-01-15T10:00:00Z',
    downloadUrl: 'https://example.com/curated-feeds-v1.2.2.apk',
    releaseNotes: '## What changed\n\n- Fixes the crash',
    htmlUrl: 'https://github.com/STRK-ND/feedapp/releases/tag/v1.2.2',
  );

  Widget harness(UpdateInfo info) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: UpdateDialog(updateInfo: info, onLater: () {}, onDownload: () {}),
    ),
  );

  testWidgets('renders version chip, actions, and release notes', (
    tester,
  ) async {
    await tester.pumpWidget(harness(sampleInfo()));

    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('Version 1.2.2'), findsOneWidget);
    expect(find.text('Released: 15/1/2026'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
    expect(find.text('Skip this version'), findsOneWidget);
    expect(find.text('Open in browser'), findsOneWidget);
    // Release notes are rendered after markdown-ish stripping.
    expect(find.text("What's new:"), findsOneWidget);
    expect(find.textContaining('Fixes the crash'), findsOneWidget);
  });

  testWidgets('Skip this version persists the ignored version', (tester) async {
    await tester.pumpWidget(harness(sampleInfo()));

    await tester.tap(find.text('Skip this version'));
    await tester.pumpAndSettle();

    // Confirmation dialog is shown first.
    expect(find.text('Ignore this update?'), findsOneWidget);

    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ignored_update_version'), '1.2.2');
  });

  testWidgets(
    'tapping Update Now shows downloading state and handles failure cleanly',
    (tester) async {
      final mockClient = MockClient((request) async {
        // Hold the download open across a frame so the in-flight spinner
        // is observable; a synchronous 500 would complete the whole async
        // chain inside the first pump and the spinner would never paint.
        await Future<void>.delayed(const Duration(seconds: 1));
        return http.Response('error', 500);
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: UpdateDialog(
              updateInfo: sampleInfo(),
              client: mockClient,
              onLater: () {},
              onDownload: () {},
            ),
          ),
        ),
      );

      expect(find.text('Update Now'), findsOneWidget);
      await tester.tap(find.text('Update Now'));
      await tester.pump(); // Starts _run; download still in flight

      // In-flight spinner is visible and label says Downloading…
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Downloading…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1)); // download fails (500)
      await tester.pumpAndSettle();

      // After failure, label switches to "Try again" and localized error text is shown
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Update failed. Try again.'), findsOneWidget);
    },
  );
}
