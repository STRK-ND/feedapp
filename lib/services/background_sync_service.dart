/// Background feed refresh via Android WorkManager.
///
/// The in-app auto-refresh Timer only runs while the app is foregrounded;
/// this service keeps the cached feed (and user-added custom sources)
/// fresh while the app is closed, so opening it shows current content.
///
/// Contract:
/// - Scheduled/cancelled from the splash flow on every launch and from the
///   Settings auto-refresh toggle, so the OS job always mirrors the
///   user's preference.
/// - The task runs in a headless isolate where `main()` never ran —
///   [runBackgroundSync] bootstraps the service locator itself.
/// - Never notifies: canonical new-article pushes already come over FCM
///   from the worker. This sync only warms the cache.
library;

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../di/service_locator.dart';
import '../utils/error_handler.dart';
import 'settings_service.dart';
import 'storage_service.dart';
import '../repositories/article_repository.dart';

/// Unique name for the periodic work — one instance app-wide.
const String kBackgroundSyncUniqueName = 'curatedfeeds.backgroundSync';

/// Task name passed to [callbackDispatcher] by WorkManager.
const String kBackgroundSyncTaskName = 'backgroundSync';

/// WorkManager enforces a 15-minute minimum for periodic work; a user
/// interval below that still schedules at 15 minutes.
Duration _clampFrequency(int refreshIntervalMinutes) {
  final minutes = refreshIntervalMinutes < 15 ? 15 : refreshIntervalMinutes;
  return Duration(minutes: minutes);
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kBackgroundSyncTaskName) return true;
    try {
      await runBackgroundSync();
      return true;
    } catch (e, s) {
      debugPrint('[BackgroundSync] task failed: $e');
      // This headless isolate never ran main(), so crash reporting must
      // bootstrap Firebase itself. Best-effort: retry still happens below.
      try {
        if (Firebase.apps.isEmpty) await Firebase.initializeApp();
        await FirebaseCrashlytics.instance.recordError(
          e,
          s,
          reason: kBackgroundSyncTaskName,
        );
      } catch (_) {}
      // Returning false asks WorkManager to retry with backoff.
      return false;
    }
  });
}

/// One background pass: delta-refresh the feed + custom sources and
/// persist. Returns the number of articles now cached, or throws —
/// [callbackDispatcher] converts that into a WorkManager retry.
///
/// Injectable [repository]/[storage]/[settings] keep this unit-testable;
/// production resolves them from getIt (bootstrapping it first, since a
/// headless isolate starts at [callbackDispatcher], not `main`).
Future<int> runBackgroundSync({
  ArticleRepository? repository,
  StorageService? storage,
  SettingsService? settings,
}) async {
  if (!getIt.isRegistered<SettingsService>()) {
    await setupServiceLocator();
  }

  final settingsService = settings ?? getIt<SettingsService>();
  final storageService = storage ?? getIt<StorageService>();

  final autoRefresh = await settingsService.getAutoRefresh();
  if (!autoRefresh) return 0;

  final repo = repository ?? getIt<ArticleRepository>();
  final result = await repo.fetchNewArticles();

  if (result.isFailure) {
    throw Exception(result.error ?? 'background refresh failed');
  }

  await storageService.saveLastRefreshTime(DateTime.now());
  ErrorHandler.addBreadcrumb(
    'Background sync complete (${result.data?.length ?? 0} cached)',
    category: 'background',
  );
  return result.data?.length ?? 0;
}

/// Mirror the autoRefresh preference into an OS-level periodic job.
/// Called on every launch and whenever the toggle changes; failures are
/// logged and swallowed — background sync must never break launch or UI.
Future<void> scheduleBackgroundSync(SettingsService settings) async {
  try {
    if (!Platform.isAndroid) return;

    final enabled = await settings.getAutoRefresh();
    if (!enabled) {
      await Workmanager().cancelByUniqueName(kBackgroundSyncUniqueName);
      return;
    }

    final interval = await settings.getRefreshInterval();
    // cancel+register = replace semantics, so interval changes take effect
    // on the next launch without depending on policy enums across versions.
    await Workmanager().cancelByUniqueName(kBackgroundSyncUniqueName);
    await Workmanager().registerPeriodicTask(
      kBackgroundSyncUniqueName,
      kBackgroundSyncTaskName,
      frequency: _clampFrequency(interval),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    ErrorHandler.addBreadcrumb(
      'Background sync scheduled every ${_clampFrequency(interval).inMinutes} min',
      category: 'background',
    );
  } catch (e) {
    // Expected in widget/unit tests (no platform channel) — stay quiet-ish.
    unawaited(
      ErrorHandler.logError('scheduleBackgroundSync skipped', error: e),
    );
  }
}
