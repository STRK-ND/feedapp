import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

/// Custom painted empty state illustrations
/// Creates visual illustrations without external assets

class EmptyStateIllustration extends StatelessWidget {
  final EmptyStateType type;
  final double size;
  final Color? color;

  const EmptyStateIllustration({
    super.key,
    required this.type,
    this.size = 120,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? AppColors.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomPaint(
      size: Size(size, size),
      painter: type == EmptyStateType.savedArticles
          ? _BookmarkIllustrationPainter(
              primaryColor: primaryColor,
              isDark: isDark,
            )
          : _FeedIllustrationPainter(
              primaryColor: primaryColor,
              isDark: isDark,
            ),
    );
  }
}

enum EmptyStateType {
  savedArticles,
  noArticles,
}

class _BookmarkIllustrationPainter extends CustomPainter {
  final Color primaryColor;
  final bool isDark;

  _BookmarkIllustrationPainter({
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Background circle
    paint.color = primaryColor.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(centerX, centerY), size.width * 0.45, paint);

    // Draw bookmark shape
    paint.color = primaryColor.withValues(alpha: 0.3);
    paint.style = PaintingStyle.fill;

    final bookmarkWidth = size.width * 0.28;
    final bookmarkHeight = size.height * 0.4;
    final bookmarkLeft = centerX - bookmarkWidth / 2;
    final bookmarkTop = centerY - bookmarkHeight / 2;

    final path = Path();
    // Start at top-left of bookmark
    path.moveTo(bookmarkLeft, bookmarkTop);
    // Line to top-right
    path.lineTo(bookmarkLeft + bookmarkWidth, bookmarkTop);
    // Line to bottom-right (with notch)
    path.lineTo(bookmarkLeft + bookmarkWidth, bookmarkTop + bookmarkHeight * 0.7);
    // Notch cutout
    path.lineTo(centerX, bookmarkTop + bookmarkHeight * 0.5);
    // Continue to bottom-left
    path.lineTo(bookmarkLeft, bookmarkTop + bookmarkHeight * 0.7);
    // Close
    path.close();

    canvas.drawPath(path, paint);

    // Inner bookmark detail
    paint.color = primaryColor.withValues(alpha: 0.6);
    final innerPath = Path();
    final innerInset = bookmarkWidth * 0.2;
    final innerBookmarkLeft = bookmarkLeft + innerInset;
    final innerBookmarkWidth = bookmarkWidth - innerInset * 2;
    final innerBookmarkHeight = bookmarkHeight * 0.6;

    innerPath.moveTo(innerBookmarkLeft, bookmarkTop + bookmarkHeight * 0.2);
    innerPath.lineTo(innerBookmarkLeft + innerBookmarkWidth, bookmarkTop + bookmarkHeight * 0.2);
    innerPath.lineTo(innerBookmarkLeft + innerBookmarkWidth, bookmarkTop + innerBookmarkHeight);
    innerPath.lineTo(centerX, bookmarkTop + innerBookmarkHeight * 0.85);
    innerPath.lineTo(innerBookmarkLeft, innerBookmarkHeight);
    innerPath.close();

    canvas.drawPath(innerPath, paint);

    // Draw decorative dots
    paint.color = primaryColor.withValues(alpha: 0.4);
    paint.style = PaintingStyle.fill;
    final dotRadius = size.width * 0.02;
    canvas.drawCircle(
      Offset(centerX - size.width * 0.15, centerY + size.height * 0.25),
      dotRadius,
      paint,
    );
    canvas.drawCircle(
      Offset(centerX + size.width * 0.15, centerY + size.height * 0.25),
      dotRadius,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeedIllustrationPainter extends CustomPainter {
  final Color primaryColor;
  final bool isDark;

  _FeedIllustrationPainter({
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Background circle
    paint.color = primaryColor.withValues(alpha: 0.1);
    canvas.drawCircle(Offset(centerX, centerY), size.width * 0.45, paint);

    // Draw RSS/feed icon
    paint.color = primaryColor.withValues(alpha: 0.3);

    // RSS dot
    canvas.drawCircle(
      Offset(centerX, centerY - size.height * 0.12),
      size.width * 0.06,
      paint,
    );

    // RSS waves
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = size.width * 0.04;
    paint.strokeCap = StrokeCap.round;

    // Inner wave
    paint.color = primaryColor.withValues(alpha: 0.5);
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY + size.height * 0.05),
        width: size.width * 0.25,
        height: size.width * 0.25,
      ),
      Radius.circular(size.width * 0.04),
    );
    canvas.drawRRect(innerRect, paint);

    // Middle wave
    paint.color = primaryColor.withValues(alpha: 0.4);
    final middleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY + size.height * 0.08),
        width: size.width * 0.38,
        height: size.width * 0.38,
      ),
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(middleRect, paint);

    // Outer wave
    paint.color = primaryColor.withValues(alpha: 0.3);
    final outerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY + size.height * 0.11),
        width: size.width * 0.51,
        height: size.width * 0.51,
      ),
      Radius.circular(size.width * 0.08),
    );
    canvas.drawRRect(outerRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Enhanced empty state widget for saved articles
class SavedArticlesEmptyState extends StatelessWidget {
  final VoidCallback? onRefresh;

  const SavedArticlesEmptyState({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom illustration
            const EmptyStateIllustration(
              type: EmptyStateType.savedArticles,
              size: 140,
            ),
            const SizedBox(height: 32),
            Text(
              'No saved articles',
              style: GoogleFonts.lexend(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Swipe right on articles to save them\nfor later reading',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 15,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Hint with animated arrow
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swipe_right_rounded,
                  size: 24,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  'Swipe right to save',
                  style: GoogleFonts.lexend(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced empty state widget for feed
class FeedEmptyState extends StatelessWidget {
  final VoidCallback? onRefresh;
  final bool isOffline;

  const FeedEmptyState({
    super.key,
    this.onRefresh,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Custom illustration
            const EmptyStateIllustration(
              type: EmptyStateType.noArticles,
              size: 140,
            ),
            const SizedBox(height: 32),
            Text(
              isOffline ? 'You\'re offline' : 'No articles yet',
              style: GoogleFonts.lexend(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isOffline
                  ? 'Check your connection and try again'
                  : 'Pull down to refresh your feed\nand discover new content',
              textAlign: TextAlign.center,
              style: GoogleFonts.lexend(
                fontSize: 15,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 32),
              // Refresh button with hint
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 28,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tap to refresh',
                    style: GoogleFonts.lexend(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}