import 'package:flutter/material.dart';
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
}

/// App configuration constants
class AppConfig {
  AppConfig._();

  // RSS feed settings
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
    'Science',
    'Sports',
    'Entertainment',
  ];
}

/// Get category color by name
Color getCategoryColor(String category) {
  switch (category) {
    case 'Tech':
      return AppColors.techPrimary;
    case 'News':
      return AppColors.newsPrimary;
    case 'Science':
      return AppColors.sciencePrimary;
    case 'Sports':
      return AppColors.sportsPrimary;
    case 'Entertainment':
      return AppColors.entertainmentPrimary;
    default:
      return AppColors.primary;
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
