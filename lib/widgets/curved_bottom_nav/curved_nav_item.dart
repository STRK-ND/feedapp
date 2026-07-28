import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/constants.dart';

/// Individual tab item for the curved bottom navigation bar.
/// Uses InkWell for reliable tap detection with splash ripple.
class CurvedNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;

  const CurvedNavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurfaceVariant;
    final color = isSelected ? selectedColor : unselectedColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: colorScheme.primary.withValues(alpha: 0.05),
        child: Semantics(
          button: true,
          label: '$label tab${isSelected ? ", selected" : ""}',
          selected: isSelected,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CurvedNavTokens.itemPadding,
              vertical: 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with scale animation
                AnimatedScale(
                  scale: isSelected
                      ? CurvedNavTokens.iconScaleSelected
                      : 1.0,
                  duration: CurvedNavTokens.iconDuration,
                  curve: CurvedNavTokens.iconCurve,
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    key: ValueKey('${index}_$isSelected'),
                    color: color,
                    size: CurvedNavTokens.iconSize,
                  ),
                ),
                const SizedBox(height: 4),
                // Label with color and weight animation
                AnimatedDefaultTextStyle(
                  duration: CurvedNavTokens.labelDuration,
                  curve: CurvedNavTokens.labelCurve,
                  style: TextStyle(
                    fontSize: CurvedNavTokens.labelFontSize,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}