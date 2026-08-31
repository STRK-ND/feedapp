import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'services/background_sync_service.dart';
import 'services/posthog_service.dart';
import 'di/service_locator.dart';
import 'screens/curated_feeds_app.dart';
import 'utils/error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // Crashlytics only sees the app once splash has initialized Firebase.
    if (Firebase.apps.isNotEmpty) {
      unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
    }
    unawaited(
      ErrorHandler.logError(
        'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
        severity: ErrorSeverity.critical,
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (Firebase.apps.isNotEmpty) {
      unawaited(
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
      );
    }
    unawaited(
      ErrorHandler.logError(
        'PlatformDispatcher error',
        error: error,
        stackTrace: stack,
        severity: ErrorSeverity.critical,
      ),
    );
    return true;
  };
  // Inert until POSTHOG_API_KEY is provided via --dart-define.
  unawaited(PostHogService.init().catchError((Object _) {}));

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    try {
      final pi = await PackageInfo.fromPlatform();
      await SentryFlutter.init((options) {
        options
          ..dsn = sentryDsn
          ..tracesSampleRate = 1.0
          ..environment = const String.fromEnvironment(
            'FLUTTER_ENV',
            defaultValue: 'production',
          )
          ..release = const String.fromEnvironment('RELEASE_VERSION').isNotEmpty
              ? const String.fromEnvironment('RELEASE_VERSION')
              : '${pi.packageName}@${pi.version}'
          ..maxBreadcrumbs = 100
          ..sampleRate = 0.25;
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Sentry init failed: $e');
    }
  }
  // Register the background-isolate entrypoint for periodic feed sync.
  // Must happen before runApp; failure must never block startup.
  try {
    await Workmanager().initialize(callbackDispatcher);
  } catch (e) {
    debugPrint('[Main] Workmanager init skipped: $e');
  }

  // CuratedFeedsApp owns the MaterialApp (Directionality, Navigator,
  // theme, l10n) and shows SplashScreen as home. Firebase + DI must be
  // ready before the first frame: the root widget's providers read the
  // locator synchronously during build.
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await setupServiceLocator();
  } catch (e) {
    debugPrint('[Main] Startup init failed: $e');
  }
  runApp(const CuratedFeedsApp());

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}
