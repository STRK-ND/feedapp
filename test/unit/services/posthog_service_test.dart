import 'package:flutter_test/flutter_test.dart';

import 'package:curatedfeeds/services/posthog_service.dart';

// No dart-defines are passed to `flutter test`, so PostHogService runs
// unconfigured here — this asserts the inert path stays a safe no-op and
// never touches platform channels.
void main() {
  test('is inert when unconfigured: all calls complete without error', () async {
    expect(PostHogService.configured, isFalse);
    await PostHogService.init();
    await PostHogService.capture('app_open', {'k': 'v'});
    await PostHogService.identify('user-1');
    await PostHogService.resetUser();
  });

  test('capture accepts a null payload too', () async {
    await PostHogService.capture('event_without_props');
  });
}
