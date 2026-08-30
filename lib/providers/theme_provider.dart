import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/settings_service.dart';

/// Theme provider for managing app theme state
class ThemeProvider extends ChangeNotifier {
  final SettingsService _settingsService;
  // ponytail: default dark — the reskin is dark-first. An explicit saved
  // preference always wins (loadSettings() overwrites this), so we only
  // ship dark when the user has never set a theme. Upgrade path: if a
  // future default wants to honor OS choice again, set system here.
  ThemeMode _themeMode = ThemeMode.dark;
  Color _primaryColor = const Color(0xFFC4944E); // Stitch warm amber
  final Color _accentColor = const Color(0xFFC4944E); // Stitch accent

  ThemeProvider(this._settingsService);

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;

  // Dark gradient colors — ground scale for depth. Lighter at top so the
  // feed reads as a lit surface fading to ink at the bottom edge.
  static const Color darkGradientStart = Color(0xFF1A1423); // groundElev
  static const Color darkGradientMid = Color(0xFF120B1B);
  static const Color darkGradientEnd = Color(0xFF0E0814); // ground

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

  /// Apply a theme to live UI state WITHOUT persisting it. Used by the
  /// CuratedFeedsApp proxy to mirror the SettingsNotifier source of truth —
  /// persisting there would race load() and clobber the user's saved choice
  /// with the notifier's initial `system` default on every cold start.
  void applyThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
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
        fontSize: 48,
        fontWeight: FontWeight.w700,
        color: primary,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.3,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.2,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.playfairDisplay(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
        letterSpacing: -0.1,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: secondary,
        height: 1.5,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      bodySmall: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelMedium: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }

  /// Get light theme data — matched-but-secondary path. Paper ground, ink
  /// text, amber still attention-only. Cards drop to paperRaised (not a
  /// tinted container) so the surface reads flat-editorial, not glass.
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: _primaryColor,
        onPrimary: Colors.white,
        secondary: _primaryColor,
        onSecondary: Colors.white,
        tertiary: _primaryColor,
        onTertiary: Colors.white,
        error: const Color(0xFFDC3640),
        onError: Colors.white,
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF15131C),
        surfaceContainerHighest: const Color(0xFFF4F1F8),
        onSurfaceVariant: const Color(0xFF6B6877),
        outline: const Color(0xFFE5E7EB),
        outlineVariant: const Color(0xFFE5E7EB),
        inverseSurface: const Color(0xFF15131C),
        onInverseSurface: const Color(0xFFF4F1F8),
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F1F8),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: const Color(0xFF15131C),
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF15131C)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFFFFF),
        selectedItemColor: Color(0xFFC4944E),
        unselectedItemColor: Color(0xFF6B6877),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      textTheme: _buildTextTheme(
        const Color(0xFF15131C),
        const Color(0xFF6B6877),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF15131C)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFC4944E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        contentTextStyle: GoogleFonts.dmSans(color: const Color(0xFF15131C)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor;
          }
          return const Color(0xFF6B6877);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primaryColor.withValues(alpha: 0.5);
          }
          return const Color(0xFFE5E7EB);
        }),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Color(0xFFFFFFFF),
        textColor: Color(0xFF15131C),
        iconColor: Color(0xFF15131C),
      ),
      // Spec §10 quality floor: keyboard/d-pad focus must be visible on
      // every IconButton and tappable card — amber at 12%.
      focusColor: _primaryColor.withValues(alpha: 0.12),
      splashColor: _primaryColor.withValues(alpha: 0.08),
    );
  }

  /// Get dark theme data — the reskin's hero surface. Near-black ground,
  /// paper-on-ground text, amber reserved for attention (colorScheme.primary
  /// *only*). Surface tokens map to the ground elevation scale so cards
  /// and sheets read as layered stone, not lit glass.
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: _primaryColor,
        onPrimary: const Color(0xFF0E0814),
        secondary: _primaryColor,
        onSecondary: const Color(0xFF0E0814),
        tertiary: _primaryColor,
        onTertiary: const Color(0xFF0E0814),
        error: const Color(0xFFE0626A),
        onError: const Color(0xFF0E0814),
        surface: const Color(0xFF1A1423), // groundElev
        onSurface: const Color(0xFFF8F7F4), // paperOnGround
        surfaceContainerHighest: const Color(0xFF12091A),
        onSurfaceVariant: const Color(0xFF8A8590), // paperSoft
        outline: const Color(0xFF27212E), // ruleOnGround
        outlineVariant: const Color(0xFF27212E),
        inverseSurface: const Color(0xFFF8F7F4),
        onInverseSurface: const Color(0xFF0E0814),
      ),
      scaffoldBackgroundColor: const Color(0xFF0E0814), // ground
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: const Color(0xFFF8F7F4),
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF8F7F4)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1423), // groundElev — no amber tint
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A1423),
        selectedItemColor: Color(0xFFC4944E),
        unselectedItemColor: Color(0xFF8A8590),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      textTheme: _buildTextTheme(
        const Color(0xFFF8F7F4),
        const Color(0xFF8A8590),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF27212E),
        thickness: 1,
      ),
      iconTheme: const IconThemeData(color: Color(0xFFF8F7F4)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFC4944E),
        foregroundColor: Color(0xFF0E0814),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1423),
        contentTextStyle: GoogleFonts.dmSans(color: const Color(0xFFF8F7F4)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF27212E), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1A1423),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accentColor;
          }
          return const Color(0xFF8A8590);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _accentColor.withValues(alpha: 0.5);
          }
          return const Color(0xFF27212E);
        }),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Color(0xFF1A1423),
        textColor: Color(0xFFF8F7F4),
        iconColor: Color(0xFFF8F7F4),
      ),
      // Spec §10 quality floor: visible focus on dark, same amber rule.
      focusColor: _accentColor.withValues(alpha: 0.12),
      splashColor: _accentColor.withValues(alpha: 0.08),
    );
  }
}
