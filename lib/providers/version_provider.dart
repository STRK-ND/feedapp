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
