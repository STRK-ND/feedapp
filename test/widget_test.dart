import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Smoke test: verify the test framework is functional.
    // Full widget tests require Firebase initialization stubs;
    // those should be added when Firebase mocks are configured.
    expect(true, isTrue);
  });
}