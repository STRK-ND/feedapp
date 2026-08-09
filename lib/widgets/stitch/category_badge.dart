import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Stitch-style category badge with clean squared design
class CategoryBadge extends StatelessWidget {
  final String category;
  final Color? backgroundColor;
  final Color? textColor;

  const CategoryBadge({
    super.key,
    required this.category,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Category: $category',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: backgroundColor ?? colorScheme.primary,
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Text(
          category,
          style: TextStyle(
            color: textColor ?? colorScheme.onPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Read time badge for cards with clock icon
class ReadTimeBadge extends StatelessWidget {
  final int minutes;

  const ReadTimeBadge({super.key, required this.minutes});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$minutes min read',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 12, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              '$minutes min read',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
