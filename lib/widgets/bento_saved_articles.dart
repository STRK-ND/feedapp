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

/// Bento Grid layout for saved articles - Stitch Design
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

    if (span == 2) {
      return _buildFeaturedCard(article, sourceName, sourceColor, index, animation);
    }
    return _buildStandardCard(article, sourceName, sourceColor, index, animation);
  }

  Widget _buildFeaturedCard(
    Article article,
    String sourceName,
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
        aspectRatio: 2.0,
        child: GestureDetector(
          onTapDown: (_) => HapticFeedback.lightImpact(),
          onTap: () => widget.onTap(index),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            widget.onToggleSave(index);
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.backgroundDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
                        color: sourceColor.withOpacity(0.1),
                      ),
                    )
                  else
                    Container(
                      color: sourceColor.withOpacity(0.1),
                    ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.backgroundDark.withOpacity(0.9),
                        ],
                        stops: const [0.4, 1.0],
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sourceName,
                            style: GoogleFonts.lexend(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.title,
                          style: GoogleFonts.lexend(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          Helpers.formatTimeAgo(article.pubDate),
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
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

  Widget _buildStandardCard(
    Article article,
    String sourceName,
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
      child: GestureDetector(
        onTapDown: (_) => HapticFeedback.lightImpact(),
        onTap: () => widget.onTap(index),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onToggleSave(index);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
                      color: sourceColor.withOpacity(0.1),
                    ),
                  )
                else
                  Container(
                    color: sourceColor.withOpacity(0.1),
                  ),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.backgroundDark.withOpacity(0.95),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sourceName,
                          style: GoogleFonts.lexend(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.title,
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Helpers.formatTimeAgo(article.pubDate),
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bookmark_outline_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No saved articles',
            style: GoogleFonts.lexend(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Swipe right on articles to save them',
            style: GoogleFonts.lexend(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// Stub to keep compatibility - can be removed later
class ExpandedArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onClose;
  final VoidCallback onToggleSave;

  const ExpandedArticleCard({
    required this.article,
    required this.onClose,
    required this.onToggleSave,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
