import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Image cache manager.
///
/// Tuned for an Android-only reader: 4-day stale window, 80 objects
/// total. Smaller than the `flutter_cache_manager` defaults (7 days /
/// 200) to limit on-disk size and battery use the prune step entails.
class AppCacheManager extends CacheManager {
  static const String key = 'appImageCache';
  static AppCacheManager? _instance;

  factory AppCacheManager() {
    _instance ??= AppCacheManager._();
    return _instance!;
  }

  AppCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 4),
          maxNrOfCacheObjects: 80,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileSystem: IOFileSystem(key),
          fileService: HttpFileService(),
        ),
      );
}

/// APK cache manager (1-day expiry, 5 objects)
class ApkCacheManager extends CacheManager {
  static const String key = 'apkCache';
  static ApkCacheManager? _instance;

  factory ApkCacheManager() {
    _instance ??= ApkCacheManager._();
    return _instance!;
  }

  ApkCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 5,
          repo: JsonCacheInfoRepository(databaseName: key),
          fileSystem: IOFileSystem(key),
          fileService: HttpFileService(),
        ),
      );
}
