import 'dart:math';
import 'package:flutter/material.dart';

import '../../utils/constants.dart' hide AppColors;
import '../../utils/design_tokens.dart';

/// CustomPainter for the reskinned bottom nav. Out: frosted-glass pill +
/// amber domed indicator + glow (reads as a glowing bubble). In: a solid
/// groundElev rail with a hairline top edge, and a small amber dot that
/// slides under the selected label. The amber appears only at the one
/// point that means "you are here" — consistent with the rest of the
/// reskin's "amber = attention only" rule. ponytail: kept the domed-path
/// math out — a flat dot is all the structure the bar needs, and a 2px
/// cap dot tracks the tab center exactly.
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

    // ── 1. Solid rail fill + hairline top edge ─────────────────────
    final bgRect = Rect.fromLTWH(0, 0, width, height);
    final bgRRect = RRect.fromRectAndRadius(
      bgRect,
      const Radius.circular(CurvedNavTokens.barRadius),
    );

    canvas.drawRRect(
      bgRRect,
      Paint()
        ..color = isDark
            ? AppColors.groundElev
            : CurvedNavTokens.lightBarFill,
    );
    canvas.drawRRect(
      bgRRect,
      Paint()
        ..color = (isDark ? AppColors.ruleOnGround : AppColors.rule)
            .withValues(alpha: 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // ── 2. Sliding amber dot — the only amber on the bar ───────────
    final fromX = _interpolateX(previousIndex, tabCenterXs);
    final toX = _interpolateX(targetIndex, tabCenterXs);
    final currentX = fromX + ((toX - fromX) * _easeCurve(animationProgress));

    // Dot rides at the top edge of the bar, centered on the active tab.
    const dotR = 1.75;
    canvas.drawCircle(
      Offset(currentX, CurvedNavTokens.indicatorTopInset + dotR),
      dotR,
      Paint()..color = AppColors.curation,
    );
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
    return t < 0.5 ? 4 * t * t * t : 1 - (pow(-2 * t + 2, 3) / 2);
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
