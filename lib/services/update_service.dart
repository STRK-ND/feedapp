import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  // GitHub repository URL for auto-updates
  static const String githubApiUrl =
      'https://api.github.com/repos/STRK-ND/feedapp/releases/latest';

  // Keys for SharedPreferences
  static const String _lastCheckedKey = 'last_update_check';
  static const String _ignoredVersionKey = 'ignored_update_version';

  /// Check for updates (throttle to at most once per hour)
  static Future<UpdateInfo?> checkForUpdates({bool forceCheck = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastChecked = prefs.getInt(_lastCheckedKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const oneHourInMs = 3600000;

      // Skip if checked within last hour (unless forced)
      if (!forceCheck && (now - lastChecked) < oneHourInMs) {
        return null;
      }

      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final latestVersion = data['tag_name'] as String;

        // Remove 'v' prefix if present
        final cleanVersion = latestVersion.startsWith('v')
            ? latestVersion.substring(1)
            : latestVersion;

        // Get current app version
        final packageInfo = await _getCurrentVersion();

        // Update last checked time
        await prefs.setInt(_lastCheckedKey, now);

        // Check if update is needed (simple version comparison)
        if (_shouldUpdate(packageInfo, cleanVersion)) {
          final ignoredVersion = prefs.getString(_ignoredVersionKey);
          // Don't show if user ignored this version
          if (ignoredVersion != cleanVersion) {
            return UpdateInfo(
              version: cleanVersion,
              releaseDate: data['published_at'] as String,
              downloadUrl: _getApkDownloadUrl(data),
              releaseNotes: data['body'] as String? ?? '',
              htmlUrl: data['html_url'] as String,
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Get the APK download URL from release assets
  static String _getApkDownloadUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List<dynamic>?;
    if (assets != null && assets.isNotEmpty) {
      // Find the APK file
      for (final asset in assets) {
        if ((asset['name'] as String).endsWith('.apk')) {
          return asset['browser_download_url'] as String;
        }
      }
    }
    // Fallback to release page
    return releaseData['html_url'] as String;
  }

  /// Compare versions to determine if update is needed
  static bool _shouldUpdate(String current, String latest) {
    final currentParts = current.split('.')..removeWhere((e) => e.isEmpty);
    final latestParts = latest.split('.')..removeWhere((e) => e.isEmpty);

    for (int i = 0; i < 3; i++) {
      final currentNum = i < currentParts.length
          ? int.tryParse(currentParts[i]) ?? 0
          : 0;
      final latestNum = i < latestParts.length
          ? int.tryParse(latestParts[i]) ?? 0
          : 0;

      if (latestNum > currentNum) return true;
      if (latestNum < currentNum) return false;
    }

    return false;
  }

  /// Get current app version
  static Future<String> _getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('Error getting package info: $e');
      return '1.0.0'; // Fallback
    }
  }

  /// Mark a version as ignored (won't show update for this version)
  static Future<void> ignoreVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoredVersionKey, version);
  }

  /// Open download URL
  static Future<bool> openDownloadUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
    return false;
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
