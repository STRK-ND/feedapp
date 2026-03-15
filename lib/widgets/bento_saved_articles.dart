import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../services/cache_manager.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../di/service_locator.dart';

/// Bento Grid layout for saved articles
/// Features different card sizes: 1x1 (standard), 2x1 (featured)
class BentoSavedArticlesGrid extends StatefulWidget {
  final List<Article> articles;
  final Function(int) onTap;
  final Function(int) onToggleSave;
  final Function(int) onDismiss;
  final bool isEmpty;

  const BentoSavedArticlesGrid({
    required this.articles,
    required this.onTap,
    required this.onToggleSave,
    required this.onDismiss,
    required this.isEmpty,
    super.key,
  });

  @override
  State<BentoSavedArticlesGrid> createState() => _BentoSavedArticlesGridState();
}

class _BentoSavedArticlesGridState extends State<BentoSavedArticlesGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BentoSavedArticlesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.articles.length != oldWidget.articles.length) {
      _entranceController.reset();
      _entranceController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmpty || widget.articles.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: BentoGridConfig.crossAxisCount,
        mainAxisSpacing: BentoGridConfig.mainAxisSpacing,
        crossAxisSpacing: BentoGridConfig.crossAxisSpacing,
        childAspectRatio: BentoGridConfig.standardRatio,
      ),
      itemCount: widget.articles.length,
      itemBuilder: (context, index) {
        final span = BentoGridConfig.getSpanForArticle(index, widget.articles.length);
        return _buildBentoCard(index, span);
      },
    );
  }

  Widget _buildBentoCard(int index, int span) {
    final article = widget.articles[index];
                final sourceColor = getIt<RssFeedService>().getSourceColorFromArticle(article);
  final sourceIcon = getIt<RssFeedService>().getSourceIconFromArticle(article);
  final sourceName = getIt<RssFeedService>().getSourceNameFromArticle(article);

    // Entrance animation with stagger
    final Animation<double> animation = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(
        (index * 0.08).clamp(0.0, 0.7),
        (0.2 + index * 0.08).clamp(0.2, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    // Featured (2-column) or standard (1-column)
    if (span == 2) {
      return _buildFeaturedCard(article, sourceName, sourceIcon, sourceColor, index, animation);
    }
    return _buildStandardCard(article, sourceName, sourceIcon, sourceColor, index, animation);
  }

  Widget _buildFeaturedCard(
    Article article,
    String sourceName,
  IconData sourceIcon,
    Color sourceColor,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20.0 * (1.0 - animation.value)),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 2.0, // Wide card
        child: Dismissible(
          key: Key('saved_${article.id}'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => widget.onDismiss(index),
          background: _buildDismissBackground(),
child: GestureDetector(
                    onTapDown: (_) => HapticFeedback.lightImpact(),
                    onTap: () => widget.onTap(index),
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      widget.onToggleSave(index);
                    },
            child: Container(
              decoration: AppCardStyles.glassDecoration(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppCardStyles.cardRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image
                    if (article.imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: article.imageUrl!,
                        fit: BoxFit.cover,
                        cacheManager: AppCacheManager(),
                        placeholder: (context, url) => Container(
                          color: AppColors.background,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: sourceColor.withValues(alpha:  0.1),
                          child: Icon(
                            sourceIcon,
                            size: 48,
                            color: sourceColor.withValues(alpha:  0.3),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: sourceColor.withValues(alpha:  0.1),
                        child: Icon(
                          sourceIcon,
                          size: 48,
                          color: sourceColor.withValues(alpha:  0.3),
                        ),
                      ),

                    // Gradient overlay for text readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha:  0.8),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Source badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha:  0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  sourceIcon,
                                  size: 12,
                                  color: sourceColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  sourceName,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: sourceColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Title
                          Text(
                            article.title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Time
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_outlined,
                                size: 12,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                Helpers.formatTimeAgo(article.pubDate),
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Save indicator
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha:  0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.favorite,
                          size: 16,
                          color: AppColors.error,
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

  Widget _buildStandardCard(
    Article article,
    String sourceName,
  IconData sourceIcon,
    Color sourceColor,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20.0 * (1.0 - animation.value)),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key('saved_${article.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => widget.onDismiss(index),
        background: _buildDismissBackground(),
child: GestureDetector(
                  onTapDown: (_) => HapticFeedback.lightImpact(),
                  onTap: () => widget.onTap(index),
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    widget.onToggleSave(index);
                  },
          child: Container(
            decoration: AppCardStyles.glassDecoration(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppCardStyles.cardRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image (top half)
                  Expanded(
                    flex: 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (article.imageUrl != null)
                          CachedNetworkImage(
                            imageUrl: article.imageUrl!,
                            fit: BoxFit.cover,
                            cacheManager: AppCacheManager(),
                            placeholder: (context, url) => Container(
                              color: AppColors.background,
                              child: const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: sourceColor.withValues(alpha:  0.1),
                              child: Icon(
                                sourceIcon,
                                color: sourceColor.withValues(alpha:  0.3),
                              ),
                            ),
                          )
                        else
                          Container(
                            color: sourceColor.withValues(alpha:  0.1),
                            child: Icon(
                              sourceIcon,
                              size: 32,
                              color: sourceColor.withValues(alpha:  0.3),
                            ),
                          ),

                        // Source badge overlay
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha:  0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(sourceIcon, size: 10, color: sourceColor),
                                const SizedBox(width: 4),
                                Text(
                                  sourceName,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: sourceColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Save indicator
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha:  0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite,
                              size: 12,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content (bottom half)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            article.title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: 10,
                                color: AppColors.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                Helpers.formatTimeAgo(article.pubDate),
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
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

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha:  0.1),
        borderRadius: BorderRadius.circular(AppCardStyles.cardRadius),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: AppColors.error,
        size: 28,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha:  0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_outline_rounded,
              size: 40,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No saved articles',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Swipe right on articles to save them for later reading',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}