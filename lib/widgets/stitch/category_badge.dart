import 'package:flutter/material.dart';
import '../../utils/constants.dart';

/// Stitch-style category badge with uppercase text and rounded pill shape
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          color: textColor ?? Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 12,
            color: isDark
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.black.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            '$minutes min read',
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.black.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Source badge for displaying article source
class SourceBadge extends StatelessWidget {
  final String sourceName;
  final Color? backgroundColor;
  final Color? textColor;

  const SourceBadge({
    super.key,
    required this.sourceName,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        sourceName,
        style: TextStyle(
          color: textColor ?? AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
