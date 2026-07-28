import 'dart:ui';
import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import 'curved_nav_indicator.dart';
import 'curved_nav_item.dart';

/// Premium curved bottom navigation bar with glassmorphism effect,
/// smooth curved animation, and clean modern design.
///
/// Uses AbsorbPointer on the blur layer so taps pass through to nav items.
/// Uses simplified layering for smooth 60fps animation.
class CurvedBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final int itemCount;

  const CurvedBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.itemCount = 3,
  });

  @override
  State<CurvedBottomNavBar> createState() => _CurvedBottomNavBarState();
}

class _CurvedBottomNavBarState extends State<CurvedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  int _previousIndex = 0;
  int _displayedIndex = 0;

  final List<double> _tabCenterXs = [];

  @override
  void initState() {
    super.initState();
    _displayedIndex = widget.selectedIndex;
    _previousIndex = widget.selectedIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: CurvedNavTokens.slideDuration,
    );
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: CurvedNavTokens.slideCurve,
      ),
    );
  }

  @override
  void didUpdateWidget(CurvedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _previousIndex = _displayedIndex;
      _displayedIndex = widget.selectedIndex;
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: CurvedNavTokens.barBottomMargin),
      child: Container(
        height: CurvedNavTokens.barHeight,
        margin: const EdgeInsets.symmetric(
          horizontal: CurvedNavTokens.barHorizontalPadding,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            final itemWidth = barWidth / widget.itemCount;

            _tabCenterXs.clear();
            for (int i = 0; i < widget.itemCount; i++) {
              _tabCenterXs.add(itemWidth * i + itemWidth / 2);
            }

            return AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(CurvedNavTokens.barRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: CurvedNavTokens.blurSigmaX,
                      sigmaY: CurvedNavTokens.blurSigmaY,
                    ),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: CurvedNavBarPainter(
                          isDark: isDark,
                          animationProgress: _slideAnimation.value,
                          previousIndex: _previousIndex,
                          targetIndex: _displayedIndex,
                          itemCount: widget.itemCount,
                          tabCenterXs: List.from(_tabCenterXs),
                        ),
                        size: Size(barWidth, CurvedNavTokens.barHeight),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (int i = 0; i < widget.itemCount; i++)
                              Expanded(
                                child: CurvedNavItem(
                                  index: i,
                                  icon: _iconForTab(i, false),
                                  selectedIcon: _iconForTab(i, true),
                                  label: _labelForTab(i),
                                  isSelected: _displayedIndex == i,
                                  onTap: () => widget.onItemSelected(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  IconData _iconForTab(int index, bool selected) {
    switch (index) {
      case 0:
        return selected ? Icons.article : Icons.article_outlined;
      case 1:
        return selected ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded;
      case 2:
        return selected ? Icons.settings : Icons.settings_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _labelForTab(int index) {
    switch (index) {
      case 0:
        return 'Feed';
      case 1:
        return 'Saved';
      case 2:
        return 'Settings';
      default:
        return '';
    }
  }
}