import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import '../repositories/article_repository.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/cache_manager.dart';
import '../services/cloud_sync_service.dart';
import '../services/settings_service.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../services/worker_feed_service.dart';
import '../services/client_feed_service.dart';
import '../services/tts_service.dart';
import '../services/feed_database.dart';
import 'package:http/http.dart' as http;

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (getIt.isRegistered<http.Client>()) {
    return;
  }

  getIt.registerLazySingleton<http.Client>(() => http.Client());

  // Services
  getIt.registerLazySingleton<FeedDatabase>(() => FeedDatabase());
  getIt.registerLazySingleton<SettingsService>(() => SettingsService());
  getIt.registerLazySingleton<StorageService>(
    () => StorageService(database: getIt<FeedDatabase>()),
  );
  // Auth + cloud sync only exist when a Firebase app is available —
  // splash initializes Firebase before this runs; plain unit tests never
  // do, and everything downstream guards with isRegistered.
  if (Firebase.apps.isNotEmpty) {
    // Keep the Crashlytics dashboard release-only.
    if (kDebugMode) {
      unawaited(
        FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false),
      );
    }
    getIt.registerLazySingleton<AuthService>(() => AuthService());
    getIt.registerLazySingleton<CloudSyncService>(
      () => CloudSyncService(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        storage: getIt<StorageService>(),
        settings: getIt<SettingsService>(),
      ),
    );
    // Wire push hooks after the sync service exists (avoids get-it
    // circular construction): local mutations mirror to Firestore when
    // signed in.
    getIt<SettingsService>().syncHooks = getIt<CloudSyncService>();
    getIt<StorageService>().syncHooks = getIt<CloudSyncService>();
    // React to sign-in/sign-out for the process lifetime (start-up sync,
    // sign-in sync, sign-out teardown). authStateChanges replays the
    // current user on listen, so no separate startup sync is needed.
    unawaited(getIt<CloudSyncService>().init());
  }
  getIt.registerLazySingleton<AppCacheManager>(() => AppCacheManager());
  getIt.registerLazySingleton<ApkCacheManager>(() => ApkCacheManager());

  getIt.registerLazySingleton<RssFeedService>(() => RssFeedService());
  getIt.registerLazySingleton<ArticleContentService>(
    () => ArticleContentService(httpClient: getIt<http.Client>()),
  );
  getIt.registerLazySingleton<WorkerFeedService>(
    () => WorkerFeedService(httpClient: getIt<http.Client>()),
  );
  getIt.registerLazySingleton<ClientFeedService>(
    () => ClientFeedService(httpClient: getIt<http.Client>()),
  );
  getIt.registerLazySingleton<TtsService>(() => TtsService());

  getIt.registerLazySingleton<ArticleRepository>(
    () => ArticleRepository(
      storageService: getIt<StorageService>(),
      workerFeedService: getIt<WorkerFeedService>(),
    ),
  );
}
