import 'package:get_it/get_it.dart';
import '../repositories/article_repository.dart';
import '../repositories/feed_repository.dart';
import '../services/storage_service.dart';
import '../services/cache_manager.dart';
import '../services/settings_service.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../services/worker_feed_service.dart';
import '../services/outbox_service.dart';
import 'package:http/http.dart' as http;

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (getIt.isRegistered<http.Client>()) {
    return;
  }

  getIt.registerLazySingleton<http.Client>(() => http.Client());

  // Services
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<AppCacheManager>(() => AppCacheManager());
  getIt.registerLazySingleton<ApkCacheManager>(() => ApkCacheManager());
  getIt.registerLazySingleton<SettingsService>(() => SettingsService());
  getIt.registerLazySingleton<OutboxService>(() => OutboxService());

  getIt.registerLazySingleton<RssFeedService>(
    () => RssFeedService(httpClient: getIt<http.Client>()),
  );
  getIt.registerLazySingleton<ArticleContentService>(
    () => ArticleContentService(httpClient: getIt<http.Client>()),
  );
  getIt.registerLazySingleton<WorkerFeedService>(
    () => WorkerFeedService(httpClient: getIt<http.Client>()),
  );

  getIt.registerLazySingleton<FeedRepository>(
    () => FeedRepository(rssFeedService: getIt<RssFeedService>()),
  );

  getIt.registerLazySingleton<ArticleRepository>(
    () => ArticleRepository(
      storageService: getIt<StorageService>(),
      workerFeedService: getIt<WorkerFeedService>(),
      outboxService: getIt<OutboxService>(),
    ),
  );
}
