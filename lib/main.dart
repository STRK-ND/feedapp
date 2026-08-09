import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'screens/splash_screen.dart';
import 'utils/error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
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
  runApp(const SplashScreen());

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}
