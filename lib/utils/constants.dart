import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App-wide constants and color definitions
class AppColors {
  AppColors._();

  // Primary colors - Stitch Design System
  static const Color primary = Color(
    0xFFC4944E,
  ); // Warm amber (editorial primary)
  static const Color primary10 = Color(0x1AC4944E); // 10% opacity
  static const Color primary5 = Color(0x0DC4944E); // 5% opacity
  static const Color background = Color(
    0xFF1A1423,
  ); // Deep charcoal (dark mode)
  static const Color backgroundLight = Color(0xFFF7F5F8); // Light mode bg
  static const Color backgroundDark = Color(
    0xFF1A1423,
  ); // Stitch dark background
  static const Color surface = Color(0xFFFFFFFF); // Pure white

  // Text colors
  static const Color textPrimary = Color(0xFF1A1B2E); // Deep charcoal
  static const Color textSecondary = Color(0xFF6B7280); // Muted gray
  static const Color textTertiary = Color(0xFF9CA3AF); // Light gray
  static const Color divider = Color(0xFFE5E7EB); // Subtle border

  // Semantic colors
  static const Color error = Color(0xFFDC3640); // Refined red
  static const Color success = Color(0xFF057A55); // Deep emerald

  // Category colors - Tech
  static const Color techPrimary = Color(0xFF3B82F6);
  static const Color techSecondary = Color(0xFF60A5FA);

  // Category colors - News
  static const Color newsPrimary = Color(0xFFDC2626);

  // Category colors - Science
  static const Color sciencePrimary = Color(0xFF0891B2);
  static const Color scienceSecondary = Color(0xFF22D3EE);

  // Category colors - Sports
  static const Color sportsPrimary = Color(0xFF059669);
  static const Color sportsSecondary = Color(0xFF34D399);

  // Category colors - Entertainment
  static const Color entertainmentPrimary = Color(0xFF7C3AED);

  // Category colors - Gaming
  static const Color gamingPrimary = Color(0xFF8B5CF6);
  static const Color gamingSecondary = Color(0xFFA78BFA);
}

/// App configuration constants
class AppConfig {
  AppConfig._();

  // App info
  static const String appName = 'Curated Feeds';
  static String? _cachedVersion;

  /// App version — loaded from PackageInfo, falls back to '0.0.0'
  static Future<String> getVersion() async {
    _cachedVersion ??= (await PackageInfo.fromPlatform()).version;
    return _cachedVersion!;
  }

  // Worker API settings
  static String get workerApiUrl => const String.fromEnvironment(
    'WORKER_API_URL',
    defaultValue: 'https://curated-feeds-worker.raj15400881.workers.dev/',
  );
  static const int workerTimeoutSeconds = 8;

  /// Shared secret header sent to the worker on app-side API calls.
  /// Empty when not compiled in via --dart-define=WORKER_API_SECRET=...
  static const String workerApiSecret = String.fromEnvironment(
    'WORKER_API_SECRET',
    defaultValue: '',
  );

  /// Support email — shown in Settings and used for the mailto link.
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'rajatkashyap7062@gmail.com',
  );

  static const int rssTimeoutSeconds = 8;
  static const int maxArticlesPerSource = 20;

  // Pro monetization caps. ponytail: single cap for now — add a
  // ProLimits class only if a second cap lands.
  static const int freeSavedArticlesCap = 25;

  // Cache settings
  static const int maxCachedArticles = 1000;

  // XML parsing limits (for security)
  static const int maxXmlSizeBytes = 5 * 1024 * 1024; // 5MB

  // APK download settings
  static const int maxApkDownloadSizeMB = 100;

  // Category list
  static const List<String> categories = [
    'All',
    'Tech',
    'News',
    'Sports',
    'Entertainment',
    'Gaming',
  ];
}

// ============================================================================
// Hero Tag Helpers
// ============================================================================

/// Get article image hero tag for shared element transitions
String getArticleHeroTag(String articleId) => 'article-hero-$articleId';

// ============================================================================
// Card Design Styles - Glassmorphism & Dimensional
// ============================================================================

/// Card decoration styles for glassmorphism effect
class AppCardStyles {
  AppCardStyles._();

  // Border radius - Stitch Design System
  static const double cardRadius = 20.0;
  static const double imageRadius = 16.0;
  static const double badgeRadius = 10.0;
  static const double buttonRadius = 14.0;

  // Animation durations - Standardized
  static const Duration microDuration = Duration(
    milliseconds: 150,
  ); // Haptic feedback, instant
  static const Duration quickDuration = Duration(
    milliseconds: 250,
  ); // Button states
  static const Duration standardDuration = Duration(
    milliseconds: 300,
  ); // Default UI transitions
  static const Duration fadeInDuration = Duration(
    milliseconds: 300,
  ); // Image fade
  static const Duration emphasisDuration = Duration(
    milliseconds: 400,
  ); // FAB, bounce
  static const Duration staggerDuration = Duration(
    milliseconds: 700,
  ); // Feed stagger
  static const Duration shimmerDuration = Duration(
    milliseconds: 1500,
  ); // Loading shimmer
  static const Curve bounceCurve = Curves.easeOutBack;

  /// Category chip glass effect
  static BoxDecoration chipDecoration(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(badgeRadius),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
    );
  }

  /// Bottom sheet glass effect
  static BoxDecoration bottomSheetDecoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.surface.withValues(alpha: 0.95),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.10),
          blurRadius: 40,
          offset: const Offset(0, -20),
        ),
      ],
    );
  }
}

// ============================================================================
// Bento Grid Layout Constants
// ============================================================================

/// Bento grid layout configuration for saved articles
class BentoGridConfig {
  BentoGridConfig._();

  /// Grid cross-axis count
  static const int crossAxisCount = 2;

  /// Main axis spacing
  static const double mainAxisSpacing = 16;

  /// Cross axis spacing
  static const double crossAxisSpacing = 16;

  /// Card aspect ratios
  static const double standardRatio = 1.2; // 1x1 standard
  static const double wideRatio = 0.6; // 2x1 featured

  /// Breakpoints for responsive columns
  static const int phoneColumns = 2;
  static const int tabletColumns = 3;

  /// Get span for article based on importance
  static int getSpanForArticle(int index, int totalCount) {
    // First article is featured (2 spans)
    if (index == 0 && totalCount > 2) return 2;
    // Every 5th article is featured
    if (index > 0 && index % 5 == 0 && totalCount > 5) return 2;
    return 1;
  }
}

// ============================================================================
// Curved Bottom Navigation Bar Tokens
// ============================================================================

/// Design tokens for the premium curved bottom navigation bar
class CurvedNavTokens {
  CurvedNavTokens._();

  // Dimensions
  static const double barHeight = 72.0;
  static const double barRadius = 28.0;
  static const double barBottomMargin = 16.0;
  static const double barHorizontalPadding = 16.0;
  static const double itemPadding = 16.0;
  static const double iconSize = 24.0;
  static const double iconScaleSelected = 1.15;
  static const double labelFontSize = 11.0;
  static const double indicatorCornerRadius = 14.0;
  static const double indicatorDomeHeight = 6.0;
  static const double indicatorTopInset = 6.0;
  static const double indicatorBottomInset = 6.0;

  // Glassmorphism
  static const double blurSigmaX = 12.0;
  static const double blurSigmaY = 12.0;

  // Light mode colors
  static const Color lightBarFill = Color(0xFFFFFFFF);
  static const double lightBarFillAlpha = 0.72;
  static const Color lightBarBorder = Color(0xFFFFFFFF);
  static const double lightBarBorderAlpha = 0.5;
  static const Color lightIndicatorFill = AppColors.primary;
  static const double lightIndicatorFillAlpha = 0.18;
  static const double lightGlowAlpha = 0.15;

  // Dark mode colors
  static const Color darkBarFill = Color(0xFF1A1B2E);
  static const double darkBarFillAlpha = 0.18;
  static const Color darkBarBorder = Color(0xFFFFFFFF);
  static const double darkBarBorderAlpha = 0.08;
  static const Color darkIndicatorFill = AppColors.primary;
  static const double darkIndicatorFillAlpha = 0.2;
  static const double darkGlowAlpha = 0.2;

  // Animations
  static const Duration slideDuration = Duration(milliseconds: 300);
  static const Duration iconDuration = Duration(milliseconds: 250);
  static const Duration labelDuration = Duration(milliseconds: 300);
  static const Curve slideCurve = Curves.easeOutCubic;
  static const Curve iconCurve = Curves.easeOutBack;
  static const Curve labelCurve = Curves.easeOutCubic;
}
