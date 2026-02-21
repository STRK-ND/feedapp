import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../themes/editorial_theme.dart';

/// View mode enum
enum ViewMode { cards, list }

/// Editorial Design System - Curated Feeds
/// Style: Sophisticated, content-first, print-inspired
/// High-end magazine aesthetic with meticulous attention to typography and hierarchy

class AppColors {
  AppColors._();

  // === PRIMARY PALETTE === (From EditorialTheme)
  static const Color primary = EditorialTheme.accentRust;
  static const Color primaryVariant = Color(0xFF9C3A22);
  static const Color primaryLight = Color(0xFFD0684D);
  static const Color primarySurface = Color(0xFFF9F3F1);

  // Secondary
  static const Color secondary = EditorialTheme.accentSage;
  static const Color secondaryVariant = Color(0xFF5C6557);
  static const Color secondarySurface = Color(0xFFF4F5F3);

  // === NEUTRAL PALETTE ===
  static const Color background = EditorialTheme.paperWhite;
  static const Color surface = EditorialTheme.paperWhite;
  static const Color surfaceVariant = Color(0xFFF9F9F9);
  static const Color surfaceElevated = EditorialTheme.paperWhite;

  // Text hierarchy
  static const Color textPrimary = EditorialTheme.inkBlack;
  static const Color textSecondary = EditorialTheme.graphite;
  static const Color textTertiary = EditorialTheme.warmGrey;
  static const Color textOnPrimary = EditorialTheme.paperWhite;
  static const Color textOnSecondary = EditorialTheme.inkBlack;

  // === SEMANTIC COLORS ===
  static const Color success = Color(0xFF2E7D32);
  static const Color successSurface = Color(0xFFE8F5E8);
  static const Color error = Color(0xFFB71C1C);
  static const Color errorSurface = Color(0xFFFFEBEE);
  static const Color warning = EditorialTheme.accentRust;
  static const Color warningSurface = Color(0xFFFFF5F2);
  static const Color info = EditorialTheme.accentMidnight;
  static const Color infoSurface = Color(0xFFF0F4F8);

  // === BORDER & DIVIDER ===
  static const Color border = Color(0xFFEEEEEE);
  static const Color borderSubtle = Color(0xFFF5F5F5);
  static const Color borderFocus = EditorialTheme.inkBlack;

  // === SHADOWS ===
  static const Color shadowSmall = Color(0x0D000000);
  static const Color shadowMedium = Color(0x1A000000);
  static const Color shadowLarge = Color(0x29000000);
  static const Color shadowCard = Color(0x0D000000);

  // === CATEGORY COLORS (Editorial theme) ===
  static const Color techPrimary = EditorialTheme.tech;
  static const Color techSurface = Color(0xFFF5F3FF);

  static const Color newsPrimary = EditorialTheme.news;
  static const Color newsSurface = Color(0xFFFFEBEE);

  static const Color sciencePrimary = EditorialTheme.science;
  static const Color scienceSurface = Color(0xFFF1F8E9);

  static const Color sportsPrimary = EditorialTheme.sports;
  static const Color sportsSurface = Color(0xFFFFF3E0);

  static const Color entertainmentPrimary = EditorialTheme.entertainment;
  static const Color entertainmentSurface = Color(0xFFFCE4EC);

  // === SWIPE INDICATORS ===
  static const Color swipeSave = Color(0xFF2E7D32);
  static const Color swipeDismiss = Color(0xFFB71C1C);
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

/// Enterprise Typography - Lexend-inspired professional design
/// Lexend: Designed to improve reading speed and reduce eye strain
final appTextTheme = GoogleFonts.lexendTextTheme().copyWith(
  // Display styles for hero sections
  displayLarge: GoogleFonts.lexend(
    fontSize: 57,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.12,
    color: AppColors.textPrimary,
  ),
  displayMedium: GoogleFonts.lexend(
    fontSize: 45,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.16,
    color: AppColors.textPrimary,
  ),
  displaySmall: GoogleFonts.lexend(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.22,
    color: AppColors.textPrimary,
  ),

  // Headlines
  headlineLarge: GoogleFonts.lexend(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  ),
  headlineMedium: GoogleFonts.lexend(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  ),
  headlineSmall: GoogleFonts.lexend(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  ),

  // Titles
  titleLarge: GoogleFonts.lexend(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  ),
  titleMedium: GoogleFonts.lexend(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    color: AppColors.textPrimary,
  ),
  titleSmall: GoogleFonts.lexend(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  ),

  // Body text - optimized for readability
  bodyLarge: GoogleFonts.lexend(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.6,
    color: AppColors.textPrimary,
  ),
  bodyMedium: GoogleFonts.lexend(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
    color: AppColors.textPrimary,
  ),
  bodySmall: GoogleFonts.lexend(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
    color: AppColors.textSecondary,
  ),

  // Labels
  labelLarge: GoogleFonts.lexend(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  ),
  labelMedium: GoogleFonts.lexend(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textSecondary,
  ),
  labelSmall: GoogleFonts.lexend(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textTertiary,
  ),
);
