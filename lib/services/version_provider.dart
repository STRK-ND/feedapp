import 'package:package_info_plus/package_info_plus.dart';

/// Centralized version provider that caches version information
/// to avoid multiple calls to PackageInfo and prevent race conditions.
class VersionProvider {
  VersionProvider._();

  /// Cached package info
  static PackageInfo? _packageInfo;

  /// Get the current app version (cached)
  static Future<String> getVersion() async {
    final info = await _getPackageInfo();
    return info.version;
  }

  /// Get the current app build number (cached)
  static Future<String> getBuildNumber() async {
    final info = await _getPackageInfo();
    return info.buildNumber;
  }

  /// Get the version including build number (cached)
  /// Returns format like "1.2.3+4" or just "1.2.3" if build is missing
  static Future<String> getVersionWithBuild() async {
    final info = await _getPackageInfo();

    if (info.buildNumber.isNotEmpty && info.buildNumber != '0') {
      return '${info.version}+${info.buildNumber}';
    }
    return info.version;
  }

  /// Get just the version without build number (cached)
  /// Returns format like "1.2.3" even if version is "1.2.3+4"
  static Future<String> getVersionWithoutBuild() async {
    final version = await getVersion();
    // Remove build number if present
    if (version.contains('+')) {
      return version.split('+')[0];
    }
    return version;
  }

  /// Compare versions and return true if newer version is available
  /// Returns true if latest version > current version
  static Future<bool> isNewerVersionAvailable(String latestVersion) async {
    try {
      final current = await getVersionWithoutBuild();
      // Remove build number from latest version too (for consistency)
      var cleanLatest = latestVersion;
      if (cleanLatest.startsWith('v')) {
        cleanLatest = cleanLatest.substring(1);
      }
      if (cleanLatest.contains('+')) {
        cleanLatest = cleanLatest.split('+')[0];
      }

      final currentParts = current.split('.')..removeWhere((e) => e.isEmpty);
      final latestParts = cleanLatest.split('.')..removeWhere((e) => e.isEmpty);

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
    } catch (e) {
      return false;
    }
  }

  /// Get or initialize cached package info
  static Future<PackageInfo> _getPackageInfo() async {
    if (_packageInfo != null) {
      return _packageInfo!;
    }

    _packageInfo = await PackageInfo.fromPlatform();
    return _packageInfo!;
  }

  /// Clear cached package info (useful for testing)
  static void clearCache() {
    _packageInfo = null;
  }
}
