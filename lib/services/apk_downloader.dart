import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef ProgressCallback = void Function(int received, int total);

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

class ApkDownloader {
  const ApkDownloader._();

  /// Download APK from URL with progress reporting
  static Future<DownloadResult> downloadApk(
    String url, {
    required ProgressCallback onProgress,
  }) async {
    try {
      // Create temporary directory for download
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/update_${DateTime.now().millisecondsSinceEpoch}.apk');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        return DownloadResult(
          success: false,
          errorMessage: 'Failed to download APK: ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength;
      final sink = file.openWrite();
      int downloadedBytes = 0;

      final stream = response.stream;
      await for (var data in stream) {
        sink.write(data);
        downloadedBytes += data.length;
        onProgress(downloadedBytes, contentLength ?? 1);
      }

      await sink.close();

      return DownloadResult(
        success: true,
        filePath: file.path,
      );
    } catch (e) {
      debugPrint('Download error: $e');
      return DownloadResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Clean up old downloaded APKs
  static Future<void> cleanupOldDownloads() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);

      final files = dir.listSync().toList();
      final apkFiles = files.where((f) => f.path.endsWith('.apk'));

      // Delete APKS older than 7 days
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      for (final file in apkFiles) {
        final stat = file.statSync();
        if (stat.modified.isBefore(cutoffDate)) {
          await file.delete();
          debugPrint('Deleted old APK: ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }

  /// Calculate APK file size in MB
  static String getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
