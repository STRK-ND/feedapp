import 'package:flutter/material.dart';

class EditorialTheme {
  // Typography
  static const String _displayFont = 'Playfair Display';
  static const String _bodyFont = 'Inter';

  // Color Palette - Editorial/Magazine
  static const Color primaryBlack = Color(0xFF1A1A1A);
  static const Color primaryWhite = Color(0xFFFAFAFA);
  static const Color paperWhite = Color(0xFFFEFEFE);
  static const Color inkBlack = Color(0xFF0F0F0F);

  // Accent Colors
  static const Color accentRust = Color(0xFFB7472A);
  static const Color accentSage = Color(0xFF7A8471);
  static const Color accentMidnight = Color(0xFF2C3E50);

  // Neutral Tones
  static const Color graphite = Color(0xFF2D2D2D);
  static const Color charcoal = Color(0xFF3A3A3A);
  static const Color warmGrey = Color(0xFF6B6B6B);
  static const Color lightGrey = Color(0xFF9A9A9A);
  static const Color paperGrey = Color(0xFFE8E8E8);

  // Category Colors
  static const Color tech = Color(0xFF5E35B1);
  static const Color news = Color(0xFF1E88E5);
  static const Color science = Color(0xFF43A047);
  static const Color sports = Color(0xFFFB8C00);
  static const Color entertainment = Color(0xFFD81B60);

  // Text Color Mappings
  static const Color primaryText = inkBlack;
  static const Color secondaryText = graphite;
  static const Color tertiaryText = warmGrey;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: paperWhite,
      canvasColor: paperWhite,

      // AppBar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: paperWhite,
        foregroundColor: inkBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: _displayFont,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: inkBlack,
        ),
      ),

      // Typography
      textTheme: TextTheme(
        // Display Headlines
        displayLarge: TextStyle(
          fontFamily: _displayFont,
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          height: 1.1,
          color: inkBlack,
        ),
        displayMedium: TextStyle(
          fontFamily: _displayFont,
          fontSize: 36,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.2,
          color: inkBlack,
        ),
        displaySmall: TextStyle(
          fontFamily: _displayFont,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.25,
          color: inkBlack,
        ),

        // Headlines
        headlineLarge: TextStyle(
          fontFamily: _displayFont,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.25,
          color: inkBlack,
        ),
        headlineMedium: TextStyle(
          fontFamily: _displayFont,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
          height: 1.3,
          color: inkBlack,
        ),
        headlineSmall: TextStyle(
          fontFamily: _displayFont,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          height: 1.35,
          color: inkBlack,
        ),

        // Body Text
        bodyLarge: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 18,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.15,
          height: 1.6,
          color: graphite,
        ),
        bodyMedium: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.15,
          height: 1.6,
          color: graphite,
        ),
        bodySmall: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.1,
          height: 1.5,
          color: warmGrey,
        ),

        // Labels
        labelLarge: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: graphite,
        ),
        labelMedium: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: warmGrey,
        ),
        labelSmall: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: lightGrey,
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: paperWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: inkBlack,
          foregroundColor: paperWhite,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
            fontFamily: _bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentRust,
          textStyle: TextStyle(
            fontFamily: _bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: graphite,
        size: 24,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: paperGrey,
        disabledColor: paperGrey,
        selectedColor: accentSage,
        secondarySelectedColor: accentSage,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: TextStyle(
          fontFamily: _bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: graphite,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: paperGrey,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
