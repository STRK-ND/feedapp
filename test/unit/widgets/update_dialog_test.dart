import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Note: "Update Now" is deliberately NOT tapped — it performs a real
  // network download + install flow.
}
