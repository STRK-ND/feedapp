import 'package:flutter/material.dart';

class TinderTheme {
  // === TINDER COLOR PALETTE ===
  // Signature gradient colors
  static const Color primaryGradientStart = Color(0xFFFD267A);
  static const Color primaryGradientEnd = Color(0xFFFF6037);
  static const Color secondaryGradientStart = Color(0xFF6A11CB);
  static const Color secondaryGradientEnd = Color(0xFF2575FC);

  // Accent colors
  static const Color rose = Color(0xFFFFC0CB);
  static const Color purpleAccent = Color(0xFF9B59B6);
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color goldAccent = Color(0xFFFFD700);

  // Status colors
  static const Color likeGreen = Color(0xFF4CAF50);
  static const Color dislikeRed = Color(0xFFF44336);
  static const Color superLikeBlue = Color(0xFF2196F3);

  // Backgrounds
  static const Color bgDark = Color(0xFF121212);
  static const Color bgMedium = Color(0xFF1E1E1E);
  static const Color bgLight = Color(0xFF2A2A2A);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textTertiary = Color(0xFF757575);

  // Gradient definitions
  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryGradientStart, primaryGradientEnd],
      );

  static LinearGradient get secondaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [secondaryGradientStart, secondaryGradientEnd],
      );

  static LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bgDark, bgMedium, bgDark],
      );

  // Theme data
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: bgDark,
        brightness: Brightness.dark,

        // Typography - Bold, playful fonts
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
          displaySmall: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.2,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textSecondary,
            height: 1.5,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textSecondary,
            height: 1.4,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textTertiary,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
          labelMedium: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textSecondary,
          ),
          labelSmall: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: textTertiary,
          ),
        ),

        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),

        // Card theme
        cardTheme: CardThemeData(
          color: bgMedium.withOpacity(0.9),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),

        // Icon theme
        iconTheme: const IconThemeData(
          color: textPrimary,
          size: 24,
        ),

        // Button themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: primaryGradientStart,
            foregroundColor: textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: cyanAccent,
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}
