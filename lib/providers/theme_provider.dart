import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';

/// Theme provider for managing app theme state
class ThemeProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  ThemeMode _themeMode = ThemeMode.system;
  Color _primaryColor = const Color(0xFFC4944E); // Stitch warm amber
  Color _accentColor = const Color(0xFFC4944E); // Stitch accent

  ThemeProvider(this._settingsService);

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;
  
  /// Light theme colors - Stitch "Curated" design
  static const Color _lightBackground = Color(0xFFF7F5F8); // Stitch light background
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightTextPrimary = Color(0xFF1A1B2E);
  static const Color _lightTextSecondary = Color(0xFF6B7280);
  static const Color _lightDivider = Color(0xFFE5E7EB);
  
  /// Dark theme colors
  static const Color _darkBackground = Color(0xFF190F23);
  static const Color _darkSurface = Color(0xFF1E1E2E);
  static const Color _darkTextPrimary = Color(0xFFF8F7F4);
  static const Color _darkTextSecondary = Color(0xFF9CA3AF);
  static const Color _darkDivider = Color(0xFF374151);

  // Dark gradient colors — sophisticated near-black to charcoal
  static const Color darkGradientStart = Color(0xFF121214);
  static const Color darkGradientMid = Color(0xFF18181B);
  static const Color darkGradientEnd = Color(0xFF1C1C1F);
  
  /// Initialize theme from settings
  Future<void> init() async {
    _themeMode = await _settingsService.getThemeMode();
    _primaryColor = await _settingsService.getPrimaryColor();
    try {
      notifyListeners();
    } catch (_) {
      // Ignore if disposed during async gap
    }
  }
  
  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _settingsService.setThemeMode(mode);
    notifyListeners();
  }
  
  /// Set primary color
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    await _settingsService.setPrimaryColor(color);
    notifyListeners();
  }
  
  /// Build text theme — shared between light and dark
  static TextTheme _buildTextTheme(Color primary, Color secondary) {
    return TextTheme(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 48, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 32, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.3,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 24, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 22, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.playfairDisplay(
        fontSize: 18, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.1,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16, fontWeight: FontWeight.w400, color: primary, height: 1.6,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w400, color: secondary, height: 1.5,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: primary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w400, color: secondary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12, fontWeight: FontWeight.w500, color: secondary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 10, fontWeight: FontWeight.w500, color: secondary,
      ),
    );
  }

  /// Get light theme data
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.light,
        primary: _primaryColor,
        secondary: _accentColor,
        surface: _lightSurface,
      ),
      scaffoldBackgroundColor: _lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: _lightTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: _lightTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: _lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightSurface,
        selectedItemColor: _primaryColor,
        unselectedItemColor: _lightTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: _buildTextTheme(_lightTextPrimary, _lightTextSecondary),
      dividerTheme: DividerThemeData(
        color: _lightDivider,
        thickness: 1,
      ),
      iconTheme: IconThemeData(
        color: _lightTextPrimary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightSurface,
        contentTextStyle: GoogleFonts.dmSans(color: _lightTextPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return _lightTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor.withValues(alpha:  0.5);
          }
          return _lightDivider;
        }),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: _lightSurface,
        textColor: _lightTextPrimary,
        iconColor: _primaryColor,
      ),
    );
  }
  
  /// Get dark theme data
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
        primary: _primaryColor,
        secondary: _accentColor,
        surface: _darkSurface,
      ),
      scaffoldBackgroundColor: _darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: _darkTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: _darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        color: _darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurface,
        selectedItemColor: _accentColor,
        unselectedItemColor: _darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: _buildTextTheme(_darkTextPrimary, _darkTextSecondary),
      dividerTheme: DividerThemeData(
        color: _darkDivider,
        thickness: 1,
      ),
      iconTheme: IconThemeData(
        color: _darkTextPrimary,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurface,
        contentTextStyle: GoogleFonts.dmSans(color: _darkTextPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accentColor;
          }
          return _darkTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accentColor.withValues(alpha:  0.5);
          }
          return _darkDivider;
        }),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: _darkSurface,
        textColor: _darkTextPrimary,
        iconColor: _accentColor,
      ),
    );
  }
}