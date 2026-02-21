import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/error_handler.dart';

/// Service for handling APK installation with permission management
class InstallationService {
  const InstallationService._();

  /// Install an APK file with proper Android permission handling
  static Future<bool> installApk(String filePath) async {
    try {
      // Verify file exists
      final file = File(filePath);
      if (!file.existsSync()) {
        ErrorHandler.logError('APK file not found', error: filePath);
        throw Exception('APK file not found at $filePath');
      }

      // For Android 8.0+, we need to request install permission
      if (Platform.isAndroid) {
        // First, try to open the APK directly - this will prompt for permission if needed
        final uri = Uri.parse('file://$filePath');

        // Try to open with ACTION_VIEW (recommended for newer Android)
        final intentUrl = 'intent://$filePath#Intent;action=android.intent.action.VIEW;scheme=file;type=application/vnd.android.package-archive;end';

        if (await canLaunchUrl(Uri.parse(intentUrl))) {
          final success = await launchUrl(
            Uri.parse(intentUrl),
            mode: LaunchMode.externalApplication,
          );
          return success;
        } else {
          // Fallback: show error and direct user to settings manually
          ErrorHandler.logError(
            'Failed to open APK installer. APK installation may be disabled on this device.',
            error: 'Install from unknown sources permission may be required',
          );
          throw Exception(
            'Unable to launch APK installer. Please ensure "Install from unknown sources" permission is enabled in Settings.',
          );
        }
      }

      ErrorHandler.logError(
        'APK installation not supported on this platform',
        error: Platform.operatingSystem,
      );
      throw Exception('APK installation is only supported on Android');
    } catch (e) {
      ErrorHandler.logError('Installation error', error: e);
      rethrow;
    }
  }

  /// Check if APK file is valid and can be installed
  static bool isValidApk(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return false;
      }

      // Check file size (minimum reasonable APK size)
      final size = file.lengthSync();
      if (size < 1024) {
        return false; // Too small to be a valid APK
      }

      // Check extension
      if (!filePath.toLowerCase().endsWith('.apk')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
