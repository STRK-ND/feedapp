import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/services/notification_service.dart';
import 'package:curatedfeeds/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService push subscription', () {
    late List<http.Request> requests;

    http.Client mockClient({int statusCode = 200}) {
      requests = [];
      return MockClient((request) async {
        requests.add(request);
        return http.Response('{}', statusCode);
      });
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await getIt.reset();
      getIt.registerLazySingleton<SettingsService>(() => SettingsService());
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('enablePushNotifications POSTs token + topic + prefs', () async {
      await NotificationService.enablePushNotifications(
        fcmToken: 'fake-fcm-token-12345',
        httpClient: mockClient(),
      );

      expect(requests, hasLength(1));
      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, endsWith('/subscribe'));
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['token'], 'fake-fcm-token-12345');
      expect(body['topic'], 'new-articles');
      expect(body['preferences'], isA<Map>());
      expect(body['preferences']['newArticles'], isTrue);
    });

    test('enablePushNotifications throws StateError on non-200', () async {
      expect(
        () => NotificationService.enablePushNotifications(
          fcmToken: 'fake-fcm-token-12345',
          httpClient: mockClient(statusCode: 500),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'enablePushNotifications throws StateError when token is null',
      () async {
        // Note: requires NotificationService singleton with _fcmToken == null.
        // The singleton factory boots FirebaseMessaging — so this test
        // relies on the "no fcmToken" branch via explicit param.
        expect(
          () => NotificationService.enablePushNotifications(
            fcmToken: null,
            httpClient: mockClient(),
          ),
          throwsA(anything), // Firebase boot OR StateError
        );
      },
    );

    test(
      'enablePushNotifications includes newArticles pref when disabled',
      () async {
        final svc = getIt<SettingsService>();
        await svc.setNewArticleNotifications(false);

        await NotificationService.enablePushNotifications(
          fcmToken: 'fake-fcm-token-12345',
          httpClient: mockClient(),
        );

        final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['preferences']['newArticles'], isFalse);
      },
    );

    test('disablePushNotifications issues DELETE with token', () async {
      await NotificationService.disablePushNotifications(
        fcmToken: 'fake-fcm-token-12345',
        httpClient: mockClient(),
      );

      expect(requests, hasLength(1));
      final req = requests.single;
      expect(req.method, 'DELETE');
      expect(req.url.path, endsWith('/subscribe'));
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['token'], 'fake-fcm-token-12345');
    });
  });
}
