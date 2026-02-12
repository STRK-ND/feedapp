import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/error_handler.dart';

typedef ProgressCallback = void Function(int received, int total);

/// Download result containing success status and file info
class DownloadResult {
  final bool success;
  final String? errorMessage;
  final String? filePath;

  DownloadResult({
    required this.success,
    this.errorMessage,
    this.filePath,
  });
}

/// Secure APK downloader with validation and size limits
class ApkDownloader {
  const ApkDownloader._();

  /// Allowed download hosts (whitelist for security)
  static const List<String> allowedHosts = [
    'github.com',
    'githubusercontent.com',
    'api.github.com',
  ];

  /// Validate download URL against whitelist and format
  static bool _isValidDownloadUrl(String url) {
    if (!Helpers.isValidUrl(url)) {
      return false;
    }

    // Check if URL ends with .apk
    if (!url.toLowerCase().endsWith('.apk')) {
      // Allow GitHub URLs since they redirect to APK downloads
      if (!url.contains('github.com') && !url.contains('githubusercontent.com')) {
        return false;
      }
    }

    // Check host whitelist
    final uri = Uri.parse(url);
    final host = uri.host.toLowerCase();

    for (final allowedHost in allowedHosts) {
      if (host == allowedHost || host.endsWith('.$allowedHost')) {
        return true;
      }
    }

    return false;
  }

  /// Download APK from URL with progress reporting and security validation
  static Future<DownloadResult> downloadApk(
    String url, {
    required ProgressCallback onProgress,
  }) async {
    // Security: Validate URL
    if (!_isValidDownloadUrl(url)) {
      ErrorHandler.logError(
        'Invalid download URL: $url',
        severity: ErrorSeverity.high,
      );
      return DownloadResult(
        success: false,
        errorMessage: 'Invalid download URL. Only downloads from trusted sources are allowed.',
      );
    }

    // Security: Validate URL is HTTPS
    final uri = Uri.parse(url);
    if (uri.scheme != 'https') {
      ErrorHandler.logError(
        'Non-HTTPS download URL: $url',
        severity: ErrorSeverity.high,
      );
      return DownloadResult(
        success: false,
        errorMessage: 'Secure downloads only. URL must use HTTPS.',
      );
    }

    try {
      // Create temporary directory for download
      final tempDir = await getTemporaryDirectory();
      final fileName = 'update_${DateTime.now().millisecondsSinceEpoch}.apk';
      final file = File('${tempDir.path}/$fileName');

      // Security: Check file path doesn't contain directory traversal
      if (!fileName.contains('update_') || fileName.contains('..')) {
        ErrorHandler.logError(
          'Invalid filename detected: $fileName',
          severity: ErrorSeverity.critical,
        );
        return DownloadResult(
          success: false,
          errorMessage: 'Invalid filename.',
        );
      }

      // Stream the download to validate size
      final request = http.StreamedRequest('GET', uri);
      final response = await request.send();

      if (response.statusCode != 200) {
        ErrorHandler.logError(
          'Download failed with status: ${response.statusCode}',
          severity: ErrorSeverity.high,
        );
        return DownloadResult(
          success: false,
          errorMessage: 'Failed to download APK: ${response.statusCode}',
        );
      }

      // Security: Validate Content-Type
      final contentType = response.headers['content-type'];
      if (contentType != null &&
          !contentType.toLowerCase().contains('octet-stream') &&
          !contentType.toLowerCase().contains('application/vnd.android')) {
        // GitHub releases might not set correct content type, so we verify the URL ends with .apk
        if (!url.toLowerCase().endsWith('.apk')) {
          ErrorHandler.logError(
            'Invalid Content-Type: $contentType',
            severity: ErrorSeverity.high,
          );
          return DownloadResult(
            success: false,
            errorMessage: 'Invalid download content type.',
          );
        }
      }

      // Get content length for size validation
      final contentLength = response.contentLength;
      const maxSize = AppConfig.maxApkDownloadSizeMB * 1024 * 1024; // Convert to bytes

      if (contentLength != null && contentLength > maxSize) {
        ErrorHandler.logError(
          'APK download too large: ${contentLength ~/ (1024 * 1024)}MB',
          severity: ErrorSeverity.high,
        );
        return DownloadResult(
          success: false,
          errorMessage: 'Download too large. Max size is ${AppConfig.maxApkDownloadSizeMB}MB.',
        );
      }

      // Write to file with size tracking
      final sink = file.openWrite();
      int downloadedBytes = 0;

      await for (final data in response.stream) {
        sink.write(data);
        downloadedBytes += data.length;

        // Security: Check size limit during download
        if (downloadedBytes > maxSize) {
          await sink.close();
          await file.delete();
          ErrorHandler.logError(
            'Download exceeded size limit',
            severity: ErrorSeverity.high,
          );
          return DownloadResult(
            success: false,
            errorMessage: 'Download exceeded maximum size limit.',
          );
        }

        onProgress(downloadedBytes, contentLength ?? maxSize);
      }

      await sink.close();

      // Verify file was created and has content
      final fileStat = file.statSync();
      if (fileStat.size == 0) {
        ErrorHandler.logError(
          'Downloaded file is empty',
          severity: ErrorSeverity.high,
        );
        return DownloadResult(
          success: false,
          errorMessage: 'Download failed: Empty file.',
        );
      }

      return DownloadResult(
        success: true,
        filePath: file.path,
      );
    } catch (e) {
      ErrorHandler.logError('Download error', error: e, severity: ErrorSeverity.high);
      return DownloadResult(
        success: false,
        errorMessage: ErrorHandler.getUserMessage(e),
      );
    }
  }

  /// Clean up old downloaded APKs
  static Future<void> cleanupOldDownloads() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);

      if (!dir.existsSync()) {
        return;
      }

      final files = dir.listSync().toList();
      final apkFiles = files.whereType<File>().where((f) => f.path.endsWith('.apk'));

      // Delete APKS older than 7 days
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));

      for (final file in apkFiles) {
        try {
          final stat = file.statSync();
          if (stat.modified.isBefore(cutoffDate)) {
            await file.delete();
            ErrorHandler.logError('Deleted old APK', error: file.path);
          }
        } catch (e) {
          ErrorHandler.logError('Failed to delete old APK', error: file.path);
        }
      }
    } catch (e) {
      ErrorHandler.logError('Cleanup error', error: e, severity: ErrorSeverity.low);
    }
  }

  /// Calculate APK file size in human-readable format
  static String getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
