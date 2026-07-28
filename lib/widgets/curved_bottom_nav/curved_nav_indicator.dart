import 'dart:math';
import 'package:flutter/material.dart';

import '../../utils/constants.dart';

/// CustomPainter that draws the frosted glass pill background,
/// the animated curved indicator (with upward dome), and the glow effect.
class CurvedNavBarPainter extends CustomPainter {
  final bool isDark;
  final double animationProgress; // 0.0–1.0 slide progress
  final int previousIndex;
  final int targetIndex;
  final int itemCount;
  final List<double> tabCenterXs; // Actual center X positions of each tab

  CurvedNavBarPainter({
    required this.isDark,
    required this.animationProgress,
    required this.previousIndex,
    required this.targetIndex,
    required this.itemCount,
    required this.tabCenterXs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // ── 1. Background pill ────────────────────────────────────────
    final bgRect = Rect.fromLTWH(0, 0, width, height);
    final bgRRect = RRect.fromRectAndRadius(
      bgRect,
      const Radius.circular(CurvedNavTokens.barRadius),
    );

    final bgFillPaint = Paint()
      ..color = (isDark
              ? CurvedNavTokens.darkBarFill
              : CurvedNavTokens.lightBarFill)
          .withValues(
              alpha: isDark
                  ? CurvedNavTokens.darkBarFillAlpha
                  : CurvedNavTokens.lightBarFillAlpha);
    canvas.drawRRect(bgRRect, bgFillPaint);

    // Border
    final borderPaint = Paint()
      ..color = (isDark
              ? CurvedNavTokens.darkBarBorder
              : CurvedNavTokens.lightBarBorder)
          .withValues(
              alpha: isDark
                  ? CurvedNavTokens.darkBarBorderAlpha
                  : CurvedNavTokens.lightBarBorderAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(bgRRect, borderPaint);

    // ── 2. Indicator position ─────────────────────────────────────
    final fromX = _interpolateX(previousIndex, tabCenterXs);
    final toX = _interpolateX(targetIndex, tabCenterXs);
    final currentX = fromX + ((toX - fromX) * _easeCurve(animationProgress));

    final indicatorWidth =
        (width / itemCount) - (CurvedNavTokens.itemPadding * 2);
    final indicatorHeight = height -
        CurvedNavTokens.indicatorTopInset -
        CurvedNavTokens.indicatorBottomInset;

    final indicatorRect = Rect.fromCenter(
      center: Offset(currentX, height / 2),
      width: indicatorWidth,
      height: indicatorHeight,
    );

    // ── 3. Glow shadow behind indicator ───────────────────────────
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(
          alpha: isDark
              ? CurvedNavTokens.darkGlowAlpha
              : CurvedNavTokens.lightGlowAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        indicatorRect.inflate(4),
        const Radius.circular(CurvedNavTokens.indicatorCornerRadius),
      ),
      glowPaint,
    );

    // ── 4. Indicator pill with domed top ──────────────────────────
    final indicatorPath = _buildDomedPath(
      indicatorRect,
      domeHeight: CurvedNavTokens.indicatorDomeHeight,
      cornerRadius: CurvedNavTokens.indicatorCornerRadius,
    );

    final indicatorPaint = Paint()
      ..color = AppColors.primary.withValues(
          alpha: isDark
              ? CurvedNavTokens.darkIndicatorFillAlpha
              : CurvedNavTokens.lightIndicatorFillAlpha);
    canvas.drawPath(indicatorPath, indicatorPaint);
  }

  /// Get center X for a given tab index from the pre-calculated positions
  double _interpolateX(int index, List<double> positions) {
    if (index >= 0 && index < positions.length) {
      return positions[index];
    }
    // Fallback: calculate from equal spacing
    final totalWidth = positions.isEmpty ? 0 : positions.last * 2;
    final itemWidth = totalWidth / itemCount;
    return index * itemWidth + itemWidth / 2;
  }

  /// Ease-in-out curve for smooth indicator slide
  double _easeCurve(double t) {
    return t < 0.5
        ? 4 * t * t * t
        : 1 - (pow(-2 * t + 2, 3) / 2);
  }

  /// Builds a custom path: rounded rectangle with a subtle upward
  /// dome (convex arc) on the top edge.
  Path _buildDomedPath(
    Rect rect, {
    required double domeHeight,
    required double cornerRadius,
  }) {
    final path = Path();
    final w = rect.width;
    final h = rect.height;
    final left = rect.left;
    final top = rect.top;
    final r = cornerRadius;
    final dome = domeHeight;

    // Start at top-left, just before the dome begins
    path.moveTo(left + r, top + dome);

    // Top edge: quadratic bezier dome (center rises above the flat top)
    path.quadraticBezierTo(
      left + w / 2,
      top - dome * 0.5,
      left + w - r,
      top + dome,
    );

    // Right edge down to bottom-right corner
    path.lineTo(left + w - r, top + h - r);

    // Bottom-right rounded corner
    path.quadraticBezierTo(left + w, top + h, left + w, top + h);

    // Bottom edge
    path.lineTo(left + r, top + h);

    // Bottom-left rounded corner
    path.quadraticBezierTo(left, top + h, left, top + h - r);

    // Left edge back up to dome start
    path.lineTo(left + r, top + dome);

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(CurvedNavBarPainter oldDelegate) =>
      isDark != oldDelegate.isDark ||
      animationProgress != oldDelegate.animationProgress ||
      previousIndex != oldDelegate.previousIndex ||
      targetIndex != oldDelegate.targetIndex ||
      itemCount != oldDelegate.itemCount ||
      tabCenterXs.length != oldDelegate.tabCenterXs.length ||
      !_listsEqual(tabCenterXs, oldDelegate.tabCenterXs);

  bool _listsEqual(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.01) return false;
    }
    return true;
  }
}
