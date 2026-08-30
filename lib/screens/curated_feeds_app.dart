/// Root application widget — MaterialApp + bottom navigation shell.
///
/// Extracted from `splash_screen.dart` so onboarding (and tests) can
/// navigate to it without crossing the splash boundary.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_notifier.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../di/service_locator.dart';
import '../widgets/in_app_notification_banner.dart';
import '../widgets/curved_bottom_nav/curved_bottom_nav_bar.dart';
import 'feed_screen.dart';
import 'settings_screen.dart';

/// Root navigator key, owned at the MaterialApp level so cold-start
/// notification taps — which fire before the nav shell exists — can still
/// resolve a context for ScaffoldMessenger feedback (data-layer H3).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

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
            // reason, return the existing provider untouched. applyThemeMode
            // (not the persisting setThemeMode) so we never write the
            // notifier's default `system` back over a saved theme.
            return theme!..applyThemeMode(notifier.themeMode);
          },
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Curated Feeds',
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainNavigation(),
            builder: (context, child) {
              // Cap system text scaling at 1.4× so large OS fonts can't
              // break the editorial layouts (spec §10). MediaQuery here is
              // the one installed by WidgetsApp, above our subtree.
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(maxScaleFactor: 1.4),
                ),
                child: InAppNotificationOverlay(child: child!),
              );
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
  void initState() {
    super.initState();
    // Wire the notification tap → silent install path. Re-entrant
    // only for foreground taps; cold-start taps are handled in
    // [MainNavigation.didChangeDependencies] below.
    NotificationService().setUpdateNotificationTapHandler(_onUpdateTap);
    // "New articles" push taps (warm and cold-start) land on the feed tab.
    NotificationService().setNewArticleTapHandler(_onNewArticleTap);
  }

  void _onNewArticleTap(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
  }

  Future<void> _onUpdateTap(String payload) async {
    final info = await NotificationService().consumeUpdateNotificationPayload(
      payload,
    );
    if (info == null || info.version.isEmpty) return;
    await _performAutoUpdate(info);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cold-start tap: the OS opened the app because of our update
    // notification. Read the cached payload once (consume) and run
    // the same auto-install flow as a regular tap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeColdStartUpdate();
    });
  }

  Future<void> _consumeColdStartUpdate() async {
    final info = await NotificationService().consumeUpdateNotificationPayload(
      null,
    );
    if (info == null || info.version.isEmpty) return;
    await _performAutoUpdate(info);
  }

  /// Drive the silent install: download the APK to temp dir, hand it
  /// to the Android system installer via open_filex. Falls back to
  /// browser handoff if the installer intent isn't available.
  /// Shared by the warm-app tap handler and the cold-start path.
  Future<void> _performAutoUpdate(UpdateInfo info) async {
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    try {
      final handle = await UpdateService.downloadApk(
        url: info.downloadUrl,
        version: info.version,
      );
      if (!ctx.mounted) return;
      final launched = await UpdateService.triggerInstall(apkFile: handle.file);
      if (launched) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Installing ${info.version}…')),
        );
      } else {
        await UpdateService.openDownloadUrl(info.downloadUrl);
        messenger?.showSnackBar(
          const SnackBar(content: Text('Opened in browser instead.')),
        );
      }
    } catch (e) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text("Couldn't auto-update. Tap the update banner."),
        ),
      );
      debugPrint('[MainNavigation] auto-update threw: $e');
    }
  }

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
