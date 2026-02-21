import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'di/service_locator.dart';
import 'themes/tinder_theme.dart';
import 'screens/feed_screen.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize dependency injection
  await setupServiceLocator();

  runApp(const RssReaderApp());
}

class RssReaderApp extends StatelessWidget {
  const RssReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curated',
      debugShowCheckedModeBanner: false,
      theme: TinderTheme.theme.copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(TinderTheme.theme.textTheme).copyWith(
          bodyLarge: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: TinderTheme.textSecondary,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: TinderTheme.textSecondary,
            height: 1.4,
          ),
          bodySmall: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: TinderTheme.textTertiary,
          ),
        ),
      ),
      home: const RssFeedScreen(),
    );
  }
}
