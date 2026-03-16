import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../di/service_locator.dart';
import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../services/cache_manager.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'swipeable_card.dart';
import 'stitch/stitch_widgets.dart';
import '../utils/read_time_calculator.dart';

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
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                    AppColors.backgroundDark,                    AppColors.backgroundDark.withValues(alpha: 0.4),                    Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
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
    final sourceName = article.sourceName.isNotEmpty
        ? article.sourceName
        : (getIt<RssFeedService>().getSourceById(article.sourceId)?.name ?? 'Unknown');
    final sourceCategory = article.sourceCategory ?? 'Technology';
    final readTime = ReadTimeCalculator.calculateReadTime(article.description);

    return GestureDetector(
      onTap: () {
        if (isFront) {
          widget.onTap(index);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                if (article.imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    fit: BoxFit.cover,
                    cacheManager: AppCacheManager(),
                  )
                else
                  Container(color: AppColors.primary10),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        AppColors.backgroundDark,
                        AppColors.backgroundDark.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.8],
                    ),
                  ),
                ),

                // Content
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Category badges
                        Row(
                          children: [
                            CategoryBadge(category: sourceCategory),
                            const SizedBox(width: 8),
                            ReadTimeBadge(minutes: readTime),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          article.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          article.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),

                        // Read more button
                        GestureDetector(
                          onTap: () => widget.onTap(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary10,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Read Full Story',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                              ],
                            ),
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