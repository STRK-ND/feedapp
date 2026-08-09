import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../providers/version_provider.dart';
import '../utils/helpers.dart';
import 'notification_service.dart';

/// UpdateService — GitHub Releases based OTA.
///
/// Two install paths:
///  - `downloadApk` + `triggerInstall`: in-app download → Android system
///    installer via `open_filex` (Reeder-style, one tap inside our app).
///  - `openDownloadUrl`: legacy browser-handoff fallback for users
///    without the install permission or on platforms where the
///    installer intent is unavailable.
///
/// Manifest update only adds new code; existing public surface is
/// stable. `checkForUpdates` and `ignoreVersion` are unchanged.
class UpdateService {
  // GitHub repository URL for OTA update metadata
  static const String githubApiUrl =
      'https://api.github.com/repos/STRK-ND/feedapp/releases/latest';

  // Android MIME type for an APK file. Used when opening the cached
  // APK with the system installer intent.
  static const String _apkMimeType = 'application/vnd.android.package-archive';

  // Keys for SharedPreferences
  static const String _lastCheckedKey = 'last_update_check';
  static const String _ignoredVersionKey = 'ignored_update_version';

  /// Check for updates (throttle to at most once per hour).
  /// Behavior unchanged from before the OTA pass.
  /// `client` is optional and injectable so tests can mock the
  /// GitHub HTTP call; defaults to a real [http.Client].
  static Future<UpdateInfo?> checkForUpdates({
    bool forceCheck = false,
    http.Client? client,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastChecked = prefs.getInt(_lastCheckedKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const oneHourInMs = 3600000;

      if (!forceCheck && (now - lastChecked) < oneHourInMs) {
        return null;
      }

      final response = await (client ?? http.Client())
          .get(
            Uri.parse(githubApiUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final latestVersion = data['tag_name'] as String;

        // Remove 'v' prefix if present
        final cleanVersion = latestVersion.startsWith('v')
            ? latestVersion.substring(1)
            : latestVersion;

        final currentVersion = await VersionProvider.getVersionWithoutBuild();

        await prefs.setInt(_lastCheckedKey, now);

        if (Helpers.isNewerVersion(currentVersion, cleanVersion)) {
          final ignoredVersion = prefs.getString(_ignoredVersionKey);
          if (ignoredVersion != cleanVersion) {
            final info = UpdateInfo(
              version: cleanVersion,
              releaseDate: data['published_at'] as String,
              downloadUrl: _getApkDownloadUrl(data),
              releaseNotes: data['body'] as String? ?? '',
              htmlUrl: data['html_url'] as String,
            );
            // Best-effort: surface an OTA heads-up notification
            // when a published release is detected, so users who
            // don't open the app on launch day still get a nudge.
            // Silent no-op if the user disabled notifications or
            // if this version was already announced.
            try {
              await NotificationService().announceUpdate(info);
            } catch (e) {
              debugPrint('[UpdateService] announceUpdate failed: $e');
            }
            return info;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Demo of file write — always available in this codebase.
  static String _getApkDownloadUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      for (final asset in assets) {
        final name = asset['name'] as String?;
        if (name != null && name.endsWith('.apk')) {
          final url = asset['browser_download_url'] as String?;
          if (url != null) return url;
        }
      }
    }
    return releaseData['html_url'] as String? ?? '';
  }

  /// Mark a version as ignored.
  static Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoredVersionKey, version);
  }

  /// Fallback: open the APK URL in the system browser.
  /// Used when in-app download/install fails (no install permission,
  /// unsupported platform, IO error, etc.) — never strand the user.
  static Future<bool> openDownloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Download the release APK to the device temp dir.
  ///
  /// Returns a handle to the saved file. Throws (and is caught by the
  /// dialog) on network/IO failure so the caller can fall back to
  /// `openDownloadUrl`.
  ///
  /// Streamed via `http.get`, written via `dart:io` `File.writeAsBytes`
  /// (APKs are <30 MB so we keep it simple — no `flutter_downloader`).
  /// `client` is optional and injectable for tests, mirroring
  /// [checkForUpdates].
  static Future<UpdateDownloadHandle> downloadApk({
    required String url,
    required String version,
    http.Client? client,
  }) async {
    final response = await (client ?? http.Client())
        .get(Uri.parse(url))
        .timeout(const Duration(minutes: 4));
    if (response.statusCode != 200) {
      throw HttpException(
        'Download failed: ${response.statusCode}',
        uri: Uri.parse(url),
      );
    }
    final bytes = response.bodyBytes;
    final dir = await getTemporaryDirectory();
    final safeVersion = version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final file = File('${dir.path}/curatedfeeds-$safeVersion.apk');
    await file.writeAsBytes(bytes, flush: true);
    return UpdateDownloadHandle(
      file: file,
      version: version,
      sizeBytes: bytes.length,
    );
  }

  /// Hand the cached APK to the Android system installer. Returns
  /// `true` if `open_filex` resolved an installer intent, `false`
  /// otherwise (caller falls back to browser handoff).
  static Future<bool> triggerInstall({required File apkFile}) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final fileExists = await apkFile.exists();
    if (!fileExists) {
      debugPrint('[UpdateService] APK missing at ${apkFile.path}');
      return false;
    }
    final result = await OpenFilex.open(apkFile.path, type: _apkMimeType);
    // result.type contains a string status. Anything other than
    // 'done' / 'opened' means we did not successfully start the
    // installer.
    if (result.type != ResultType.done) {
      debugPrint(
        '[UpdateService] triggerInstall failed: ${result.type} — ${result.message}',
      );
      return false;
    }
    return true;
  }
}

class UpdateInfo {
  final String version;
  final String releaseDate;
  final String downloadUrl;
  final String releaseNotes;
  final String htmlUrl;

  UpdateInfo({
    required this.version,
    required this.releaseDate,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.htmlUrl,
  });
}

/// A handle to a downloaded APK on disk. Returned by `downloadApk`
/// for the dialog to pass into `triggerInstall`.
class UpdateDownloadHandle {
  final File file;
  final String version;
  final int sizeBytes;

  const UpdateDownloadHandle({
    required this.file,
    required this.version,
    required this.sizeBytes,
  });
}
