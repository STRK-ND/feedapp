import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Sentry.init(
    (d) => d
      // DSN from environment config (set via --dart-define=SENTRY_DSN=...)
      ..dsn = const String.fromEnvironment('SENTRY_DSN',
          defaultValue: 'https://5a81b0922d1df36c77c139171ad66f18@o4511126921674752.ingest.de.sentry.io/4511126925344848')
      // Performance monitoring - sample 100% in debug, 25% in release
      ..tracesSampleRate = 1.0
      // Set environment from environment config
      ..environment = const String.fromEnvironment('FLUTTER_ENV',
          defaultValue: 'production')
      // Set release version for tracking (set via --dart-define=RELEASE_VERSION=...)
      ..release = const String.fromEnvironment('RELEASE_VERSION',
          defaultValue: 'com.curatedfeeds@1.0.1')
      // Enable breadcrumb tracking for user actions
      ..maxBreadcrumbs = 100
      // Sample rate for errors (25% in production)
      ..sampleRate = 0.25,
    appRunner: () => runApp(const CuratedFeedsApp()),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
}

class CuratedFeedsApp extends StatelessWidget {
  const CuratedFeedsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}