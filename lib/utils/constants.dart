import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

/// View mode enum
enum ViewMode { cards, list }

/// App-wide constants and color definitions
class AppColors {
  AppColors._();

  // Primary colors
  static const Color primary = Color(0xFF1A1B4D); // Deep midnight blue
  static const Color accent = Color(0xFFC9A962); // Muted gold
  static const Color background = Color(0xFFF8F7F4); // Cream white
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
  static const Color newsSecondary = Color(0xFFEF4444);

  // Category colors - Science
  static const Color sciencePrimary = Color(0xFF0891B2);
  static const Color scienceSecondary = Color(0xFF22D3EE);

  // Category colors - Sports
  static const Color sportsPrimary = Color(0xFF059669);
  static const Color sportsSecondary = Color(0xFF34D399);

  // Category colors - Entertainment
  static const Color entertainmentPrimary = Color(0xFF7C3AED);
  static const Color entertainmentSecondary = Color(0xFFA78BFA);

  // Category colors - Gaming
  static const Color gamingPrimary = Color(0xFF8B5CF6);
  static const Color gamingSecondary = Color(0xFFA78BFA);
}

/// App configuration constants
class AppConfig {
  AppConfig._();

  // App info
  static const String appName = 'Curated Feeds';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;

  // Worker API settings
  static const String workerApiUrl = 'https://curated-feeds-worker.raj15400881.workers.dev/';
  static const int workerTimeoutSeconds = 15;

  // RSS feed settings (deprecated - using Worker API instead)
  static const int rssTimeoutSeconds = 8;
  static const int maxArticlesPerSource = 20;

  // Cache settings
  static const int maxCachedArticles = 1000;
  static const int maxImageCacheSizeMB = 100;

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

/// Get category color by name
Color getCategoryColor(String category) {
  switch (category) {
    case 'Tech':
      return AppColors.techPrimary;
    case 'News':
      return AppColors.newsPrimary;
    case 'Sports':
      return AppColors.sportsPrimary;
    case 'Entertainment':
      return AppColors.entertainmentPrimary;
    case 'Gaming':
      return AppColors.gamingPrimary;
    default:
      return AppColors.primary;
  }
}

/// Get category icon by name - Travel-style icons
IconData getCategoryIcon(String category) {
  switch (category) {
    case 'All':
      return Icons.explore_outlined;
    case 'Tech':
      return Icons.computer_outlined;
    case 'News':
      return Icons.newspaper_outlined;
    case 'Sports':
      return Icons.sports_soccer_outlined;
    case 'Entertainment':
      return Icons.movie_outlined;
    case 'Gaming':
      return Icons.sports_esports_outlined;
    default:
      return Icons.label_outline;
  }
}

// ============================================================================
// Card Design Styles - Glassmorphism & Dimensional
// ============================================================================

/// Card decoration styles for glassmorphism effect
class AppCardStyles {
  AppCardStyles._();

  // Border radius
  static const double cardRadius = 24.0;
  static const double imageRadius = 20.0;
  static const double badgeRadius = 12.0;
  static const double buttonRadius = 12.0;

  // Animation durations
  static const Duration pressDuration = Duration(milliseconds: 150);
  static const Duration fadeInDuration = Duration(milliseconds: 300);
  static const Duration bounceDuration = Duration(milliseconds: 400);
  static const Curve bounceCurve = Curves.easeOutBack;

  /// Standard card shadow (with colored accent)
  static List<BoxShadow> cardShadow(Color sourceColor) => [
    BoxShadow(
      color: sourceColor.withValues(alpha: 0.12),
      blurRadius: 40,
      offset: const Offset(0, 20),
      spreadRadius: -8,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 15,
      offset: const Offset(0, 8),
    ),
  ];

  /// Pressed state shadow (reduced depth)
  static List<BoxShadow> pressedShadow(Color sourceColor) => [
    BoxShadow(
      color: sourceColor.withValues(alpha: 0.2),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  /// Glassmorphism decoration for cards
  static BoxDecoration glassDecoration({
    double radius = cardRadius,
    double opacity = 0.7,
    double borderOpacity = 0.3,
  }) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.5),
          blurRadius: 5,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  /// Glassmorphism for dark mode
  static BoxDecoration glassDecorationDark({
    double radius = cardRadius,
    double opacity = 0.15,
    double borderOpacity = 0.1,
  }) {
    return BoxDecoration(
      color: const Color(0xFF1A1B2E).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  /// Category chip glass effect
  static BoxDecoration chipDecoration(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(badgeRadius),
      border: Border.all(
        color: color.withValues(alpha: 0.3),
        width: 1,
      ),
    );
  }

  /// Bottom sheet glass effect
  static BoxDecoration bottomSheetDecoration() {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(28),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
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
  static const double tallRatio = 1.8; // 1x2 vertical

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

/// App-wide text theme
final appTextTheme = GoogleFonts.dmSansTextTheme().copyWith(
  headlineLarge: GoogleFonts.playfairDisplay(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
  ),
  headlineMedium: GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  ),
  headlineSmall: GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  ),
  titleLarge: GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  ),
  titleMedium: GoogleFonts.dmSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  ),
  bodyLarge: GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
    height: 1.6,
  ),
  bodyMedium: GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
    height: 1.5,
  ),
  labelLarge: GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    color: AppColors.textPrimary,
  ),
);