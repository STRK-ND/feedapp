import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for image caching with size limits
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
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 200,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileSystem: IOFileSystem(key),
            fileService: HttpFileService(),
          ),
        );
}

/// Cache manager for APK downloads
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
