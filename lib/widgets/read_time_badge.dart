import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/read_time_calculator.dart';
import '../models/article.dart';
import '../utils/constants.dart';

/// Stitch-style read time badge widget
class ReadTimeBadge extends StatelessWidget {
  final Article article;

  const ReadTimeBadge({
    required this.article,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final readTime = ReadTimeCalculator.calculateReadTime(article);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
          ? Colors.white.withValues(alpha: 0.2) // glass effect for dark
          : AppColors.primary.withValues(alpha: 0.8), // solid primary for light
        borderRadius: BorderRadius.circular(999), // pill shape
        border: isDark ? Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ) : null,
      ),
      child: Text(
        readTime,
        style: GoogleFonts.lexend(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isDark ? Colors.white : AppColors.backgroundDark,
        ),
      ),
    );
  }
}