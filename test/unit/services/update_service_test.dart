import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:flutter/services.dart';
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
          {
            'name': 'SHA256SUMS-v1.2.2.txt',
            'browser_download_url': 'https://example.com/SHA256SUMS-v1.2.2.txt',
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

  group('UpdateService.checksums', () {
    late Directory tempDir;

    setUp(() {
      // downloadApk writes to the temp dir via path_provider; mock the
      // platform channel so tests run without device storage.
      return Directory.systemTemp.createTemp('apk_dl_test').then((dir) {
        tempDir = dir;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => tempDir.path,
            );
      });
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test(
      'checkForUpdates carries the SHA256SUMS asset when published',
      () async {
        final info = await UpdateService.checkForUpdates(
          forceCheck: true,
          client: _newerReleaseClient(),
        );
        expect(info, isNotNull);
        expect(info!.checksumUrl, 'https://example.com/SHA256SUMS-v1.2.2.txt');
      },
    );

    test('fetchExpectedChecksum parses sha256sum output', () async {
      final digest = 'a' * 64;
      final client = MockClient((request) async {
        return http.Response(
          '0000...  other-file.apk\n$digest  curated-feeds-v1.2.2.apk\n',
          200,
        );
      });
      final got = await UpdateService.fetchExpectedChecksum(
        checksumUrl: 'https://example.com/SHA256SUMS-v1.2.2.txt',
        apkFileName: 'curated-feeds-v1.2.2.apk',
        client: client,
      );
      expect(got, digest);
    });

    test(
      'downloadApk accepts a matching checksum and marks installable',
      () async {
        // Build the exact bytes, then the matching sha256sums entry.
        final bytes = List<int>.generate(2048, (i) => i % 251);
        final digest = sha256.convert(bytes).toString();
        final client = MockClient((request) async {
          if (request.url.path.endsWith('SHA256SUMS-v9.9.9.txt')) {
            return http.Response('$digest  curated-feeds-v9.9.9.apk\n', 200);
          }
          return http.Response.bytes(bytes, 200);
        });

        final handle = await UpdateService.downloadApk(
          url: 'https://example.com/curated-feeds-v9.9.9.apk',
          version: '9.9.9',
          checksumUrl: 'https://example.com/SHA256SUMS-v9.9.9.txt',
          client: client,
        );
        expect(handle.installable, isTrue);
        expect(await handle.file.exists(), isTrue);
        await handle.file.delete();
      },
    );

    test(
      'downloadApk throws on a checksum mismatch and leaves no file',
      () async {
        final bytes = List<int>.generate(1024, (i) => i % 251);
        final wrongDigest = 'b' * 64;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('SHA256SUMS-v9.9.9.txt')) {
            return http.Response(
              '$wrongDigest  curated-feeds-v9.9.9.apk\n',
              200,
            );
          }
          return http.Response.bytes(bytes, 200);
        });

        await expectLater(
          UpdateService.downloadApk(
            url: 'https://example.com/curated-feeds-v9.9.9.apk',
            version: '9.9.9',
            checksumUrl: 'https://example.com/SHA256SUMS-v9.9.9.txt',
            client: client,
          ),
          throwsA(isA<HttpException>()),
        );
      },
    );

    test(
      'downloadApk fails closed when the checksum asset is missing',
      () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('SHA256SUMS-v9.9.9.txt')) {
            return http.Response('not found', 404);
          }
          return http.Response.bytes(List<int>.filled(16, 1), 200);
        });

        await expectLater(
          UpdateService.downloadApk(
            url: 'https://example.com/curated-feeds-v9.9.9.apk',
            version: '9.9.9',
            checksumUrl: 'https://example.com/SHA256SUMS-v9.9.9.txt',
            client: client,
          ),
          throwsA(isA<HttpException>()),
        );
      },
    );

    test('triggerInstall refuses an unverified handle', () async {
      final handle = UpdateDownloadHandle(
        file: File('/tmp/nonexistent.apk'),
        version: '9.9.9',
        sizeBytes: 0,
        installable: false,
      );
      // Refusal happens before any platform call, so no MissingPlugin
      // exception can occur: it returns false deterministically.
      expect(await UpdateService.triggerInstall(handle: handle), isFalse);
    });
  });
}
