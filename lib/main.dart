import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'di/service_locator.dart';
import 'utils/constants.dart';
import 'screens/feed_screen.dart';
import 'services/analytics_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Log app open event
  await AnalyticsService.logAppOpen();

  // Initialize dependency injection
  await setupServiceLocator();

  runApp(const RssReaderApp());
}

class RssReaderApp extends StatelessWidget {
  const RssReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curated Feeds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: appTextTheme,
      ),
      home: const RssFeedScreen(),
    );
  }
}