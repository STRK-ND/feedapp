/// Design tokens for Curated Feeds.
///
/// Single source of truth for colors, type, spacing, motion.
/// All screens and widgets must reference these tokens — never hardcode
/// values. Lives separately from `AppColors` (which is the per-category
/// accent palette) and from `CurvedNavTokens` (which is the bottom-nav
/// subsystem).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Spacing scale. Used everywhere instead of literal ints.
class AppSpacing {
  AppSpacing._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;
  static const double s16 = 64;
}

/// Radius scale.
class AppRadius {
  AppRadius._();
  static const double chip = 8;
  static const double button = 14;
  static const double card = 20;
  static const double sheetTop = 28;
}

/// Motion tokens. Pair with `MediaQuery.disableAnimations` check at the
/// call site (already done in `GrainOverlay`, splash — extend that
/// pattern to every animated widget).
class AppMotion {
  AppMotion._();
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
  static const Curve ease = Cubic(0.32, 0.72, 0, 1);
  static const Curve springOut = Cubic(0.34, 1.56, 0.64, 1);
}

/// Color tokens. Dark-first reskin: dark is the hero surface, light is a
/// matched-but-secondary path. Amber (`curation`) is the UNREAD-ATTENTION
/// color only — never a neutral UI accent for chips, app-bar text, nav
/// fill, or buttons. That single rule is what keeps the app off the
/// generic "cream-paper + serif + terracotta" default. See the reskin
/// plan for the reasoning.
/// ponytail: two static Color painted numbers (light/dark pairs) per token
/// instead of a runtime palette generator — the ground values never
/// branch on content, so a flat list is enough and shadows nothing a
/// generator would compute.
class AppColors {
  AppColors._();

  /// Amber — attention color only. `primary` is kept as an alias so the
  /// many existing `AppColors.primary` call sites compile, but new code
  /// should read `AppColors.curation` to self-document intent.
  static const Color curation = Color(0xFFC4944E);
  static const Color edition = Color(0xFFA0773A); // dimmed amber, edges
  static const Color primary = curation;
  static const Color primaryDeep = edition;

  // Light mode — paper aesthetic (secondary path)
  static const Color paper = Color(0xFFF4F1F8);
  static const Color paperRaised = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF15131C);
  static const Color inkSoft = Color(0xFF6B6877);
  static const Color inkFaint = Color(0xFF9A97A6);
  static const Color rule = Color(0xFFE5E7EB);

  // Dark mode — editorial near-black (hero surface)
  static const Color ground = Color(0xFF0E0814);
  static const Color groundElev = Color(0xFF1A1423);
  static const Color groundDeep = Color(0xFF050308);
  static const Color paperOnGround = Color(0xFFF8F7F4);
  static const Color paperOnGroundSoft = Color(0xFF8A8590);
  static const Color paperOnGroundFaint = Color(0xFF5E5A66);
  static const Color ruleOnGround = Color(0xFF27212E);

  // Sepia reader theme — paperback
  static const Color sepiaGround = Color(0xFFF4ECD8);
  static const Color sepiaText = Color(0xFF3E2C1C);
  static const Color sepiaSoft = Color(0xFF7A5E40);
  static const Color sepiaRule = Color(0xFFDFD1B4);
  static const Color sepiaAccent = Color(0xFF8C6E45);

  // E-Ink reader theme — OLED
  static const Color einkGround = Color(0xFF000000);
  static const Color einkText = Color(0xFFE8E2D9);
  static const Color einkRule = Color(0xFF1A1A1A);
}

/// Typography. Each role has a distinct voice.
///
/// Display — Playfair Display (editorial)
/// Body — DM Sans (calm, screen-tuned)
/// Utility — JetBrains Mono (typewriter metadata)
class AppType {
  AppType._();

  static TextStyle displayLarge({Color? color}) => GoogleFonts.playfairDisplay(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.12,
    color: color,
  );

  static TextStyle displayMedium({Color? color}) => GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.15,
    color: color,
  );

  /// Italic accent — the one soft moment against the heavy dark. Use for
  /// the Folio weekday and section-eyebrow alternates. Sparingly.
  static TextStyle displayItalic({Color? color, double fontSize = 22}) =>
      GoogleFonts.playfairDisplay(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.2,
        height: 1.2,
        color: color,
      );

  static TextStyle headlineSmall({Color? color}) => GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
    color: color,
  );

  static TextStyle titleLarge({Color? color}) => GoogleFonts.playfairDisplay(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
    color: color,
  );

  static TextStyle titleMedium({Color? color}) => GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: color,
  );

  static TextStyle bodyLarge({Color? color}) => GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: color,
  );

  static TextStyle bodyMedium({Color? color}) => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: color,
  );

  static TextStyle labelLarge({Color? color}) => GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: color,
  );

  /// Section eyebrow — uppercase mono labels: TODAY, YESTERDAY, EARLIER, ABOUT.
  static TextStyle monoEyebrow({Color? color}) => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
    height: 1.2,
    color: color,
  );

  /// Numeric dateline — date / time / counts. Tabular figures so
  /// `08.17 · 14:03` columns stay aligned across rows.
  static TextStyle monoDateline({Color? color}) => GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.05,
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color,
  );

  /// Folio Rule top line — date uppercase mono like a paper masthead.
  static TextStyle folioTop({Color? color}) => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.6,
    height: 1.2,
    color: color,
  );
}

/// A simple opacity mix — Flutter's `withValues` does it but it allocates.
/// Use `AppColors.alpha(color, 0.15)` for clarity at call sites.
Color alpha(Color base, double opacity) =>
    base.withValues(alpha: opacity.clamp(0.0, 1.0));
