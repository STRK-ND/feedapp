import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';

import '../di/service_locator.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/constants.dart' hide AppColors;
import '../utils/design_tokens.dart' show AppColors;
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
      await Firebase.initializeApp();
      await setupServiceLocator();
      await NotificationService().initialize();

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
            const CuratedFeedsApp(),
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
              // Pen-stroke folio glyph animation.
              SizedBox(
                width: 96,
                height: 96,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_drawProgress, _revealProgress]),
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _FolioGlyphPainter(
                        drawProgress: _drawProgress.value,
                        revealProgress: _revealProgress.value,
                        strokeColor: AppColors.primary,
                        fillColor: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    );
                  },
                ),
              ),
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
                  final subtitleProgress =
                      (_revealProgress.value - 0.4).clamp(0.0, 1.0) / 0.6;
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

/// Pen-stroke CustomPainter for the folio glyph. 96×96 dp rounded square
/// with two column divides and small headline/text lines inside.
///
/// The animation draws strokes over time using [PathMetric.extractPath]
/// so it reads as a pen drawing itself.
class _FolioGlyphPainter extends CustomPainter {
  _FolioGlyphPainter({
    required this.drawProgress,
    required this.revealProgress,
    required this.strokeColor,
    required this.fillColor,
  });

  final double drawProgress; // 0..1 across the stroke phase
  final double revealProgress; // 0..1 across the fill/scale phase
  final Color strokeColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Outer rrect
    final outerRRect = RRect.fromRectAndRadius(
      rect.deflate(4),
      const Radius.circular(22),
    );

    // Fill — only after the stroke completes.
    if (revealProgress > 0) {
      final scale = 0.92 + 0.08 * revealProgress;
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.scale(scale, scale);
      canvas.translate(-size.width / 2, -size.height / 2);
      canvas.drawRRect(
        outerRRect,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }

    // Stroke — drawn via path metric extraction for the pen-stroke reveal.
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fullPath = _buildGlyphPath(size);
    if (drawProgress < 1.0) {
      for (final metric in fullPath.computeMetrics()) {
        final extract = metric.extractPath(0, metric.length * drawProgress);
        canvas.drawPath(extract, strokePaint);
      }
    } else {
      canvas.drawPath(fullPath, strokePaint);
    }
  }

  Path _buildGlyphPath(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Outer rounded square
    path.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, w - 8, h - 8),
        const Radius.circular(22),
      ),
    );

    // Two column dividers — vertical lines
    final col1X = w / 3;
    final col2X = 2 * w / 3;
    path.moveTo(col1X, 12);
    path.lineTo(col1X, h - 12);
    path.moveTo(col2X, 12);
    path.lineTo(col2X, h - 12);

    // Headline block — left column top (short headline lines)
    path.moveTo(12, 16);
    path.lineTo(col1X - 4, 16);
    path.moveTo(12, 20);
    path.lineTo(col1X - 6, 20);

    // Three short text lines per column
    const lineYs = [30.0, 40.0, 50.0];
    for (final y in lineYs) {
      // Left
      path.moveTo(12, y);
      path.lineTo(col1X - 4, y);
      // Center
      path.moveTo(col1X + 4, y);
      path.lineTo(col2X - 4, y);
      // Right
      path.moveTo(col2X + 4, y);
      path.lineTo(w - 12, y);
    }

    return path;
  }

  @override
  bool shouldRepaint(_FolioGlyphPainter oldDelegate) {
    return oldDelegate.drawProgress != drawProgress ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.fillColor != fillColor;
  }
}
