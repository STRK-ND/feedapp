import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../di/service_locator.dart';
import '../utils/error_handler.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/constants.dart' hide AppColors;
import '../utils/design_tokens.dart' show AppColors;
import '../widgets/app_logo.dart';
import '../widgets/folio_rule.dart';
import 'curated_feeds_app.dart';
import 'onboarding_screen.dart';
import '../repositories/article_repository.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/background_sync_service.dart';
import '../services/rss_feed_service.dart';
import '../services/analytics_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  AppLocalizations get _l10n => AppLocalizations.of(context);
  // Three beat intro: draw (600ms) → reveal (300ms) → subtitle (200ms).
  // Total ~1.4s. Init code runs in parallel underneath — the animation
  // is never a loader.
  late final AnimationController _drawController;
  late final AnimationController _revealController;

  late final Animation<double> _drawProgress;
  late final Animation<double> _revealProgress;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _drawProgress = CurvedAnimation(
      parent: _drawController,
      curve: Curves.easeInOutCubic,
    );
    _revealProgress = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutBack,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reduceMotion = MediaQuery.disableAnimationsOf(context);
      if (_reduceMotion) {
        _drawController.value = 1.0;
        _revealController.value = 1.0;
        return;
      }
      _drawController.forward();
      _drawController.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _revealController.forward();
        }
      });
    });

    _initializeApp();
  }

  @override
  void dispose() {
    _drawController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();
    const minDuration = Duration(milliseconds: 1400);

    if (!mounted) return;

    try {
      // Firebase + service locator are initialized in main() before
      // runApp — re-initializing here would throw duplicate-app.
      //
      // Notifications are isolated from the rest of the bootstrap: they
      // depend on the platform plugin layer and were the one unguarded
      // await here, so a failure in them used to skip feed init, the
      // edition counter and background sync below. Failing to register a
      // push token must never cost the user their feed.
      try {
        await NotificationService().initialize();
      } catch (e, stackTrace) {
        debugPrint('[Splash] Notification init failed, continuing: $e');
        // debugPrint is invisible in release: mirror to Sentry so a
        // systematic init failure still leaves telemetry.
        unawaited(
          ErrorHandler.logWarning(
            'Notification init failed during splash bootstrap',
            error: e,
            stackTrace: stackTrace,
          ),
        );
      }

      final articleRepository = getIt<ArticleRepository>();
      final settingsService = getIt<SettingsService>();
      await settingsService.init();
      // Load the cached source registry, then refresh the worker's
      // canonical GET /sources list in the background.
      final rssFeedService = getIt<RssFeedService>();
      await rssFeedService.init();
      unawaited(rssFeedService.refreshFromWorker());
      // Pre-load articles into repository cache
      await Future.wait([
        articleRepository.fetchSavedArticles(),
        articleRepository.fetchAllArticles(),
        AnalyticsService.logAppOpen(),
      ]);

      // Hydrate the in-process editorial edition counter from prefs.
      unawaited(FolioRuleBootstrap.hydrate(settingsService));

      // Mirror autoRefresh into an OS-level periodic job (Android).
      unawaited(scheduleBackgroundSync(settingsService));
    } catch (e) {
      debugPrint('[Splash] Initialization error: $e');
      // Continue to main screen even if init fails — app can still work with cache
    }

    if (!mounted) return;

    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }

    if (!mounted) return;

    final onboardingDone = await getIt<SettingsService>()
        .getHasCompletedOnboarding();

    if (!mounted) return;

    if (!onboardingDone) {
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      return;
    }

    await Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigation(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final background = isDark ? AppColors.ground : AppColors.paper;

    return Scaffold(
      backgroundColor: background,
      body: Semantics(
        label: 'Curated Feeds',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo arrival. The raster replaces the pen-stroke folio
              // glyph, but the beat below is unchanged: `_drawProgress`
              // drives the logo's fade and scale across its full 0..1,
              // `_revealProgress` still starts only once it completes,
              // and the 1400ms minimum dwell in _initializeApp still
              // covers the animation. The default 96 matches the native
              // splash's launch_image size, so nothing jumps at hand-off.
              AppLogo(animation: _drawProgress),
              const SizedBox(height: 28),
              // Wordmark
              FadeTransition(
                opacity: _revealProgress,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(_revealProgress),
                  child: Text(
                    AppConfig.appName,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Eyebrow — appears last.
              AnimatedBuilder(
                animation: _revealProgress,
                builder: (context, _) {
                  // easeOutBack overshoots past 1.0 — without the second
                  // clamp the derived opacity asserts in debug builds
                  // (this was the L-5 flaky test's root cause: under
                  // parallel-suite CPU contention a pump landed on an
                  // overshoot frame). Matches the paywall-screen guard.
                  final subtitleProgress =
                      ((_revealProgress.value - 0.4).clamp(0.0, 1.0) / 0.6)
                          .clamp(0.0, 1.0);
                  return Opacity(
                    opacity: subtitleProgress,
                    child: Column(
                      children: [
                        Text(
                          'A reading room.',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _l10n.splashEditionLabel(
                            EditionState.current.toString().padLeft(4, '0'),
                          ),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
