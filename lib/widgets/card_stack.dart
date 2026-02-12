import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../services/cache_manager.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'swipeable_card.dart';

/// Card stack widget for displaying articles in a swipeable stack
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

class _CardStackState extends State<CardStack>
    with TickerProviderStateMixin {
  late AnimationController _cardEntranceController;

  @override
  void initState() {
    super.initState();
    _cardEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardEntranceController.forward();
  }

  @override
  void dispose() {
    // Memory leak fix: Explicitly dispose controller
    _cardEntranceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.articles.length != oldWidget.articles.length) {
      _cardEntranceController.reset();
      _cardEntranceController.forward();
    }
  }

  Widget _buildArticleCard(Article article, int index, bool isFront) {
    final source = RssFeedService.getSourceById(article.sourceId) ??
        RssFeedService.predefinedSources.first;
    final sourceColor = source.color;

    return AnimatedBuilder(
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

        final scale = isFront
            ? 1.0
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: sourceColor.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 20),
              spreadRadius: -8,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Semantics(
          label: '${article.title}. ${article.description}. From ${source.name}. Published ${Helpers.formatTimeAgo(article.pubDate)}.',
          image: article.imageUrl != null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source badge
                  Semantics(
                    label: 'Source: ${source.name}',
                    child: Container(
                      decoration: BoxDecoration(
                        color: sourceColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            source.icon,
                            size: 14,
                            color: sourceColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            source.name,
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

                  // Hero image if available
                  if (article.imageUrl != null)
                    Semantics(
                      image: true,
                      label: 'Article image',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: CachedNetworkImage(
                          imageUrl: article.imageUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          cacheManager: AppCacheManager(),
                          placeholder: (context, url) => Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 32,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 32,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (article.imageUrl != null)
                    const SizedBox(height: 24),

                  // Article title
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        article.title,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.35,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.left,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      maxLines: 2,
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
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.divider.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) {
      return widget.emptyState;
    }

    final visibleArticles = widget.articles.take(3).toList();

    return Stack(
      children: [
        for (int i = visibleArticles.length - 1; i >= 0; i--)
          if (i == 0)
            SwipeableCard(
              key: ValueKey('card_${widget.articles[i].id}'),
              child: _buildArticleCard(
                widget.articles[i],
                i,
                true,
              ),
              onSwipeRight: () {
                widget.onSwipeRight(
                  widget.articles.indexOf(widget.articles[i]),
                );
              },
              onSwipeLeft: () {
                widget.onSwipeLeft(
                  widget.articles.indexOf(widget.articles[i]),
                );
              },
              onTap: () {
                widget.onTap(widget.articles.indexOf(widget.articles[i]));
              },
            )
          else
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: _buildArticleCard(
                  widget.articles[i],
                  i,
                  false,
                ),
              ),
            ),
      ],
    );
  }
}
