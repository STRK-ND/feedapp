import 'package:get_it/get_it.dart';
import '../repositories/article_repository.dart';
import '../repositories/feed_repository.dart';
import '../services/storage_service.dart';
import '../services/cache_manager.dart';
import '../services/settings_service.dart';

/// Global service locator instance
/// Uses GetIt for dependency injection to manage service lifecycles
final GetIt getIt = GetIt.instance;

/// Setup all service dependencies
/// This should be called before runApp in main()
Future<void> setupServiceLocator() async {
  // Register singleton services
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<AppCacheManager>(() => AppCacheManager());
  getIt.registerLazySingleton<ApkCacheManager>(() => ApkCacheManager());
  getIt.registerLazySingleton<SettingsService>(() => SettingsService());

  // Register repositories
  getIt.registerFactory<ArticleRepository>(
    () => ArticleRepository(
      storageService: getIt<StorageService>(),
      feedRepository: const FeedRepository(),
    ),
  );

  getIt.registerFactory<FeedRepository>(() => const FeedRepository());

  // Note: RssFeedService, ArticleContentService, UpdateService, VersionProvider,
  // and ApkDownloader are static utility classes and don't need DI registration.
  // They can be called directly from anywhere in the codebase.
}