import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/main.dart';

void main() {
  testWidgets('App starts with RssFeedScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RssReaderApp());
    await tester.pumpAndSettle();

    // Verify that the app title is displayed.
    expect(find.text('Curated Feeds'), findsOneWidget);

    // Verify that the bottom navigation is present with icons.
    expect(find.byIcon(Icons.rss_feed_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    // Verify that the first tab is selected and shows text.
    expect(find.text('Feeds'), findsOneWidget);
  });

  testWidgets('App theme has expected colors', (WidgetTester tester) async {
    // Build our app.
    await tester.pumpWidget(const RssReaderApp());
    await tester.pumpAndSettle();

    // Verify that the gradient background is present in the Container.
    final Container container = tester.widget(find.byType(Container).first);

    // Verify that a gradient decoration exists
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.gradient, isNotNull);
    expect(decoration.gradient, isA<LinearGradient>());
  });
}
