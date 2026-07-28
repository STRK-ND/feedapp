import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options
          ..dsn = sentryDsn
          ..tracesSampleRate = 1.0
          ..environment = const String.fromEnvironment('FLUTTER_ENV',
              defaultValue: 'production')
          ..release = const String.fromEnvironment('RELEASE_VERSION',
              defaultValue: 'com.curatedfeeds@1.0.1')
          ..maxBreadcrumbs = 100
          ..sampleRate = 0.25;
      },
      appRunner: () => runApp(const SplashScreen()),
    );
  } else {
    runApp(const SplashScreen());
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}
