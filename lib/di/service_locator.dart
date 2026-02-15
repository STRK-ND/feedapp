import 'package:get_it/get_it.dart';
import '../services/rss_feed_service.dart';
import '../services/storage_service.dart';
import '../services/cache_manager.dart';
import '../services/article_content_service.dart';
import '../services/update_service.dart';

/// Global service locator instance
final GetIt getIt = GetIt.instance;

/// Setup all service dependencies
Future<void> setupServiceLocator() async {
  // Register singleton services
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<AppCacheManager>(() => AppCacheManager());
  getIt.registerLazySingleton<ApkCacheManager>(() => ApkCacheManager());
}
