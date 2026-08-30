import 'package:posthog_flutter/posthog_flutter.dart';

/// PostHog product analytics — inert until a project key is provided via
/// --dart-define (see docs/monitoring-setup.md). Every call is a safe
/// no-op when unconfigured, so call sites never need guards.
class PostHogService {
  PostHogService._();

  static const _apiKey = String.fromEnvironment('POSTHOG_API_KEY');
  static const _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  static bool get configured => _apiKey.isNotEmpty;

  static bool _ready = false;

  static Future<void> init() async {
    if (!configured || _ready) return;
    final config = PostHogConfig(_apiKey)
      ..host = _host
      // Firebase Analytics owns lifecycle/screen events; PostHog only gets
      // explicit captures. No replay, flags, or surveys — event capture only.
      ..captureApplicationLifecycleEvents = false
      ..preloadFeatureFlags = false
      ..sendFeatureFlagEvents = false
      ..sessionReplay = false
      ..surveys = false;
    await Posthog().setup(config);
    _ready = true;
  }

  static Future<void> capture(String event, [Map<String, Object>? props]) {
    if (!_ready) return Future.value();
    return Posthog().capture(eventName: event, properties: props);
  }

  static Future<void> identify(String userId) {
    if (!_ready) return Future.value();
    return Posthog().identify(userId: userId);
  }

  static Future<void> resetUser() {
    if (!_ready) return Future.value();
    return Posthog().reset();
  }
}
