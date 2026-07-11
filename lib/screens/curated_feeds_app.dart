/// Root application widget — MaterialApp + bottom navigation shell.
///
/// Extracted from `splash_screen.dart` so onboarding (and tests) can
/// navigate to it without crossing the splash boundary.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_notifier.dart';
import '../services/settings_service.dart';
import '../di/service_locator.dart';
import '../widgets/in_app_notification_banner.dart';
import '../widgets/curved_bottom_nav/curved_bottom_nav_bar.dart';
import 'feed_screen.dart';
import 'settings_screen.dart';

class CuratedFeedsApp extends StatelessWidget {
  const CuratedFeedsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SettingsService>(create: (_) => getIt<SettingsService>()),
        // SettingsNotifier is the source of truth for prefs (theme mode,
        // body font, viewer prefs, view mode, edition). ThemeProvider
        // proxies off it so MaterialApp.themeMode updates live.
        ChangeNotifierProvider<SettingsNotifier>(
          create: (context) {
            final provider = SettingsNotifier(getIt<SettingsService>());
            provider.loadSettings();
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<SettingsNotifier, ThemeProvider>(
          create: (_) {
            final provider = ThemeProvider(getIt<SettingsService>());
            provider.init();
            return provider;
          },
          update: (_, notifier, theme) {
            // Keep the first arg non-null. If theme is null for any
            // reason, return the existing provider untouched.
            return theme!..setThemeMode(notifier.themeMode);
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Curated Feeds',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainNavigation(),
            builder: (context, child) {
              return InAppNotificationOverlay(child: child!);
            },
          );
        },
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const RssFeedScreen(),
    const SavedArticlesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: CurvedBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }
}

class SavedArticlesScreen extends StatelessWidget {
  const SavedArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RssFeedScreen(showSavedArticles: true);
  }
}
