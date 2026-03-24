import 'package:get_it/get_it.dart';
import '../repositories/article_repository.dart';
import '../repositories/feed_repository.dart';
import '../services/storage_service.dart';
import '../services/cache_manager.dart';
import '../services/settings_service.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../services/worker_feed_service.dart';
import 'package:http/http.dart' as http;

/// Global service locator instance
/// Uses GetIt for dependency injection to manage service lifecycles
final GetIt getIt = GetIt.instance;

/// Setup all service dependencies
/// This should be called before runApp in main()
Future<void> setupServiceLocator() async {
  // Allow re-registration in tests by resetting first
  if (getIt.isRegistered<http.Client>()) {
    return; // Already initialized
  }

  // Register HTTP client for dependency injection
  getIt.registerLazySingleton<http.Client>(() => http.Client());

  // Register singleton services
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<AppCacheManager>(() => AppCacheManager());
  getIt.registerLazySingleton<ApkCacheManager>(() => ApkCacheManager());
  getIt.registerLazySingleton<SettingsService>(() => SettingsService());

  // Register RSS and content services as singletons
  getIt.registerLazySingleton<RssFeedService>(
    () => RssFeedService(httpClient: getIt<http.Client>()),
  );
  getIt.registerLazySingleton<ArticleContentService>(
    () => ArticleContentService(httpClient: getIt<http.Client>()),
  );
  getIt.registerLazySingleton<WorkerFeedService>(
    () => WorkerFeedService(httpClient: getIt<http.Client>()),
  );

  // Register repositories
  getIt.registerLazySingleton<FeedRepository>(
    () => FeedRepository(rssFeedService: getIt<RssFeedService>()),
  );

  getIt.registerLazySingleton<ArticleRepository>(
    () => ArticleRepository(
      storageService: getIt<StorageService>(),
      workerFeedService: getIt<WorkerFeedService>(),
    ),
  );
}
