import 'package:flutter/material.dart';

/// The Curated Feeds logo.
///
/// A single widget because the hand-painted `_FolioGlyphPainter` this
/// replaces was duplicated byte-for-byte in `splash_screen.dart` and
/// `paywall_screen.dart` — 110 lines in each, no shared ownership, and no
/// way to know they agreed except by reading both. A two-parameter widget
/// is less code than the duplication it kills.
///
/// The asset is the full navy tile (`assets/brand/logo.png`), so the mark
/// carries its own background and needs no light/dark variant. Do not add
/// one: `AppColors.ground` (#0E0814) and the tile's own navy are close
/// enough that the tile edge simply disappears on the dark theme, which is
/// the intended look.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = defaultSize, this.animation});

  /// Matches the mark in the native splash (`launch_image.png`) so nothing
  /// jumps when the Flutter splash replaces it.
  static const double defaultSize = 96;

  /// Edge of the logo box in logical pixels. The tile is square, so this is
  /// both width and height.
  final double size;

  /// 0..1 across the logo's arrival, or null to render it settled.
  ///
  /// Owned by the caller rather than internal, because the beat offsets
  /// that coordinate logo → wordmark → tagline have to be shared with the
  /// text; hiding the controller here would force every call site to
  /// reimplement them.
  ///
  /// A raster has no strokes to draw, so the original pen-stroke beat is
  /// gone; this is its honest analogue — a slight scale-up as the fade
  /// resolves, across the caller's full timeline. No easing is applied
  /// here: both callers already drive this with an eased controller
  /// (`Curves.easeInOutCubic`), and stacking a second curve would compose
  /// into neither. A `CurvedAnimation` is deliberately not used either —
  /// this widget is stateless, so one built in `build` could never be
  /// disposed.
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final animation = this.animation;
    final logo = Image.asset(
      'assets/brand/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // A missing brand asset must degrade to an invisible box, never an
      // exception: this renders inside a splash screen whose whole job is
      // to survive a bad cold start. The log line is what makes the
      // degradation findable instead of a permanent silent blank.
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[AppLogo] failed to load assets/brand/logo.png: $error');
        return SizedBox(width: size, height: size);
      },
    );

    if (animation == null) {
      return SizedBox(width: size, height: size, child: logo);
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Clamped but never eased: the caller's curve owns the easing, and
        // the clamp is what protects against overshooting curves (the
        // wordmark's sibling curve is `easeOutBack`, which exceeds 1.0).
        final progress = animation.value.clamp(0.0, 1.0);
        return Opacity(
          // Opacity 0 short-circuits painting entirely, so the logo is not
          // rasterised at all for the first frames of the splash.
          opacity: progress,
          child: Transform.scale(scale: 0.94 + 0.06 * progress, child: child),
        );
      },
      child: logo,
    );
  }
}
