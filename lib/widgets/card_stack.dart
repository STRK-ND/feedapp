import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../services/cache_manager.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'swipeable_card.dart';

/// Card stack widget for displaying articles in a swipeable stack
/// Features: Glassmorphism, tactile press, hero image fade-in
class CardStack extends StatefulWidget {
  final List<Article> articles;
  final Function(int) onSwipeRight;
  final Function(int) onSwipeLeft;
  final Function(int) onTap;
  final Widget emptyState;
  final bool isFilterActive;

  const CardStack({
    required this.articles,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onTap,
    required this.emptyState,
    required this.isFilterActive,
    super.key,
  });

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack> with TickerProviderStateMixin {
  late AnimationController _cardEntranceController;
  int? _pressedCardIndex;

  @override
  void initState() {
    super.initState();
    _cardEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for reduced motion preference (must be in didChangeDependencies)
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.disableAnimations) {
      _cardEntranceController.value = 1.0;
    } else if (_cardEntranceController.value == 0) {
      _cardEntranceController.forward();
    }
  }

  @override
  void dispose() {
    _cardEntranceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.articles.length != oldWidget.articles.length) {
      _cardEntranceController.reset();
      final mediaQuery = MediaQuery.of(context);
      if (mediaQuery.disableAnimations) {
        _cardEntranceController.value = 1.0;
      } else {
        _cardEntranceController.forward();
      }
    }
  }

  Widget _buildGlassImage(String? imageUrl, Article article) {
    if (imageUrl == null) return const SizedBox.shrink();

    return Semantics(
      image: true,
      label: '${article.title} image',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppCardStyles.imageRadius),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheManager: AppCacheManager(),
              placeholder: (context, url) => _buildImagePlaceholder(),
              errorWidget: (context, url, error) => _buildImageError(),
            ),
            // Travel-style gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppCardStyles.imageRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity( 0.1),
                      Colors.black.withOpacity( 0.5),
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppCardStyles.imageRadius),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppCardStyles.imageRadius),
      ),
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 32,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _buildArticleCard(Article article, int index, bool isFront) {
    // Use source metadata from article (provided by Worker) or fallback to RssFeedService
    final sourceColor = RssFeedService.getSourceColorFromArticle(article);
    final sourceIcon = RssFeedService.getSourceIconFromArticle(article);
    final sourceName = article.sourceName.isNotEmpty
        ? article.sourceName
        : (RssFeedService.getSourceById(article.sourceId)?.name ?? 'Unknown');
    final isPressed = _pressedCardIndex == index;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressedCardIndex = index);
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) => setState(() => _pressedCardIndex = null),
      onTapCancel: () => setState(() => _pressedCardIndex = null),
      onTap: () {
        if (isFront) {
          widget.onTap(index);
        }
      },
      child: AnimatedBuilder(
        animation: _cardEntranceController,
        builder: (context, child) {
          final animation = CurvedAnimation(
            parent: _cardEntranceController,
            curve: Interval(
              (index * 0.1).clamp(0.0, 0.7),
              (0.3 + index * 0.1).clamp(0.3, 1.0),
              curve: Curves.easeOutQuart,
            ),
          );

          // Tactile press effect: scale down when pressed
          final pressedScale = isPressed ? 0.97 : 1.0;
          final scale = isFront
              ? pressedScale
              : 1.0 - (0.06 * (index + 1)) + (0.03 * animation.value);
          final offset = isFront ? 0.0 : -6.0 - (index * 3.0);

          return Transform.translate(
            offset: Offset(0, offset * (1 - animation.value)),
            child: Transform.scale(
              scale: scale,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            ),
          );
        },
        // Glassmorphism card decoration
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: AppCardStyles.glassDecoration(),
          child: Semantics(
            label: '$sourceName. ${article.description}. From $sourceName. Published ${Helpers.formatTimeAgo(article.pubDate)}.',
            image: article.imageUrl != null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppCardStyles.cardRadius),
                border: Border.all(
                  color: Colors.white.withOpacity( 0.5),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glassmorphism source badge
                    Semantics(
                      label: 'Source: $sourceName',
                      child: Container(
                        decoration: AppCardStyles.chipDecoration(sourceColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(sourceIcon, size: 14, color: sourceColor),
                            const SizedBox(width: 8),
                            Text(
                              sourceName,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sourceColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Hero image with fade-in
                    _buildGlassImage(article.imageUrl, article),

                    if (article.imageUrl != null) const SizedBox(height: 24),

                    // Article title - no Expanded to prevent layout issues
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        article.title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description snippet
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        article.description,
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                          letterSpacing: 0.1,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Publication time
                    Semantics(
                      label: 'Published ${Helpers.formatTimeAgo(article.pubDate)}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(AppCardStyles.badgeRadius),
                          border: Border.all(
                            color: AppColors.divider.withOpacity( 0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Helpers.formatTimeAgo(article.pubDate),
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) {
      return widget.emptyState;
    }

    // Show only ONE card at a time - no overlapping stack effect
    final article = widget.articles.first;

    return SwipeableCard(
      key: ValueKey('card_${article.id}'),
      child: _buildArticleCard(article, 0, true),
      onSwipeRight: () => widget.onSwipeRight(0),
      onSwipeLeft: () => widget.onSwipeLeft(0),
      onTap: () => widget.onTap(0),
    );
  }
}