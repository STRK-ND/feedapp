import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'di/service_locator.dart';
import 'utils/constants.dart';
import 'screens/feed_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/feed_provider.dart';
import 'repositories/article_repository.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'services/analytics_service.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize services
  await setupServiceLocator();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize FeedProvider (prevents frame drops)
  final articleRepository = getIt<ArticleRepository>();
  final feedProvider = FeedProvider(articleRepository: articleRepository);
  await feedProvider.init();

  // Log app open event
  await AnalyticsService.logAppOpen();

  runApp(CuratedFeedsApp(feedProvider: feedProvider));
}

class CuratedFeedsApp extends StatelessWidget {
  final FeedProvider feedProvider;

  const CuratedFeedsApp({super.key, required this.feedProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provide settings service
        Provider<SettingsService>(
          create: (_) => SettingsService(),
        ),

        // Provide theme provider
        ChangeNotifierProvider<ThemeProvider>(
          create: (context) {
            final provider = ThemeProvider(SettingsService());
            provider.init();
            return provider;
          },
        ),

        // Provide feed provider (already initialized)
        ChangeNotifierProvider<FeedProvider>.value(
          value: feedProvider,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const MainNavigation(),
          );
        },
      ),
    );
  }
}

/// Main navigation with bottom tabs
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF12122A).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.95),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, -8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.article_outlined,
                    selectedIcon: Icons.article,
                    label: 'Feed',
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.bookmark_outline_rounded,
                    selectedIcon: Icons.bookmark_rounded,
                    label: 'Saved',
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.settings_outlined,
                    selectedIcon: Icons.settings,
                    label: 'Settings',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;
    final selectedColor = AppColors.primary; // Stitch purple for both themes
    final unselectedColor = isDark ? Colors.white38 : AppColors.textTertiary;
    final color = isSelected ? selectedColor : unselectedColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: selectedColor.withValues(alpha: 0.3), width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Icon(
                isSelected ? selectedIcon : icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 4),
            // Animated pill indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: isSelected ? 20 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: selectedColor,
                borderRadius: BorderRadius.circular(2),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: selectedColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved articles screen - shows saved/b bookmarked articles
class SavedArticlesScreen extends StatelessWidget {
  const SavedArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RssFeedScreen(showSavedArticles: true);
  }
}
