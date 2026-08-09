import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/providers/version_provider.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/services/update_service.dart';

/// MockClient that returns a newer GitHub release (v1.2.2) by default.
MockClient _newerReleaseClient() {
  return MockClient((request) async {
    return http.Response(
      jsonEncode({
        'tag_name': 'v1.2.2',
        'published_at': '2026-01-15T10:00:00Z',
        'body': '## What changed\n\n- Fixes things',
        'html_url': 'https://github.com/STRK-ND/feedapp/releases/tag/v1.2.2',
        'assets': [
          {
            'name': 'curated-feeds-v1.2.2.apk',
            'browser_download_url':
                'https://example.com/curated-feeds-v1.2.2.apk',
          },
        ],
      }),
      200,
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService.checkForUpdates', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Curated Feeds',
        packageName: 'com.curatedfeeds',
        version: '1.0.1',
        buildNumber: '1',
        buildSignature: '',
        installTime: DateTime.fromMillisecondsSinceEpoch(0),
      );
      // VersionProvider caches PackageInfo; reset so the mock is re-read.
      VersionProvider.clearCache();
      await getIt.reset();
      // announceUpdate reads SettingsService via getIt before calling the
      // notifications plugin; it is registered here so that path resolves.
      getIt.registerLazySingleton<SettingsService>(() => SettingsService());
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('forceCheck returns UpdateInfo for a newer GitHub release', () async {
      final info = await UpdateService.checkForUpdates(
        forceCheck: true,
        client: _newerReleaseClient(),
      );

      expect(info, isNotNull);
      expect(info!.version, '1.2.2');
      expect(info.downloadUrl, 'https://example.com/curated-feeds-v1.2.2.apk');
      expect(info.releaseDate, '2026-01-15T10:00:00Z');
      expect(info.releaseNotes, contains('Fixes things'));
      expect(info.htmlUrl, contains('releases/tag/v1.2.2'));
    });

    test('returns null when release version matches the app version', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.0.1',
            'published_at': '2026-01-15T10:00:00Z',
            'body': '',
            'html_url':
                'https://github.com/STRK-ND/feedapp/releases/tag/v1.0.1',
            'assets': [
              {
                'name': 'curated-feeds-v1.0.1.apk',
                'browser_download_url':
                    'https://example.com/curated-feeds-v1.0.1.apk',
              },
            ],
          }),
          200,
        );
      });

      final info = await UpdateService.checkForUpdates(
        forceCheck: true,
        client: mockClient,
      );
      expect(info, isNull);
    });

    test('returns null on HTTP 500', () async {
      final mockClient = MockClient(
        (request) async => http.Response('oops', 500),
      );

      final info = await UpdateService.checkForUpdates(
        forceCheck: true,
        client: mockClient,
      );
      expect(info, isNull);
    });

    test('throttles: second call within window returns null even if a newer '
        'release exists', () async {
      final first = await UpdateService.checkForUpdates(
        forceCheck: true,
        client: _newerReleaseClient(),
      );
      expect(first, isNotNull);
      expect(first!.version, '1.2.2');

      // Immediately re-check WITHOUT forceCheck. The 1-hour throttle window
      // (last_update_check was just written) short-circuits before any HTTP
      // call, so the newer release is not surfaced again.
      final second = await UpdateService.checkForUpdates(
        client: _newerReleaseClient(),
      );
      expect(second, isNull);
    });
  });

  // Note: `announceUpdate` (flutter_local_notifications `.show`) throws
  // MissingPluginException under `flutter test`. That is expected and handled:
  // checkForUpdates wraps the call in try/catch (see update_service.dart), so
  // the returned UpdateInfo is unaffected.
}
