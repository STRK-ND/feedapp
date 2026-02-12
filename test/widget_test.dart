import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/main.dart';

void main() {
  testWidgets('App starts with RssFeedScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RssReaderApp());

    // Pump once to handle synchronous initialization
    await tester.pump();

    // Handle the update check timer (2 second delay) by pumping to 3 seconds
    await tester.pump(const Duration(seconds: 3));

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

    // Pump and handle the timer
    await tester.pump(const Duration(seconds: 3));

    // Verify that a Container with gradient decoration exists
    final containers = find.byType(Container);
    expect(containers, findsWidgets);

    // Find the first container with a BoxGradient
    bool foundGradient = false;
    for (final element in containers.evaluate()) {
      final widget = element.widget as Container;
      if (widget.decoration is BoxDecoration) {
        final boxDecoration = widget.decoration as BoxDecoration;
        if (boxDecoration.gradient is LinearGradient) {
          foundGradient = true;
          break;
        }
      }
    }

    expect(foundGradient, isTrue);
  });
}
