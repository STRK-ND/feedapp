import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../services/cache_manager.dart';
import '../providers/settings_notifier.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../di/service_locator.dart';
import 'empty_state_illustrations.dart';

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
  late ColorScheme _colorScheme;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: AppCardStyles.slowDuration,
    );
    _entranceController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _colorScheme = Theme.of(context).colorScheme;
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
    return Consumer<SettingsNotifier>(
      builder: (context, settings, _) {
        if (widget.isEmpty || widget.articles.isEmpty) {
          return _buildEmptyState();
        }

        final imageMaxWidth = settings.dataSaverMode ? 400 : 800;

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
            final span = BentoGridConfig.getSpanForArticle(
              index,
              widget.articles.length,
            );
            return _buildBentoCard(
              index,
              span,
              settings.showImages,
              imageMaxWidth,
            );
          },
        );
      },
    );
  }

  Widget _buildBentoCard(
    int index,
    int span,
    bool showImages,
    int imageMaxWidth,
  ) {
    final article = widget.articles[index];
    final sourceColor = getIt<RssFeedService>().getSourceColorFromArticle(
      article,
    );
    final sourceName = getIt<RssFeedService>().getSourceNameFromArticle(
      article,
    );

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
      return _buildFeaturedCard(
        article,
        sourceName,
        sourceColor,
        index,
        animation,
        showImages,
        imageMaxWidth,
      );
    }
    return _buildStandardCard(
      article,
      sourceName,
      sourceColor,
      index,
      animation,
      showImages,
      imageMaxWidth,
    );
  }

  Widget _buildFeaturedCard(
    Article article,
    String sourceName,
    Color sourceColor,
    int index,
    Animation<double> animation,
    bool showImages,
    int imageMaxWidth,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20.0 * (1.0 - animation.value)),
          child: FadeTransition(opacity: animation, child: child),
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
              color: _colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  if (article.imageUrl != null && showImages)
                    CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      width: imageMaxWidth.toDouble(),
                      fit: BoxFit.cover,
                      cacheManager: AppCacheManager(),
                      memCacheWidth: imageMaxWidth,
                      placeholder: (context, url) =>
                          Container(color: _colorScheme.surface),
                      errorWidget: (context, url, error) =>
                          Container(color: sourceColor.withValues(alpha: 0.1)),
                    )
                  else
                    Container(color: sourceColor.withValues(alpha: 0.1)),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _colorScheme.surface.withValues(alpha: 0.9),
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
                            color: _colorScheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            sourceName,
                            style: GoogleFonts.lexend(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _colorScheme.primary,
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
                            color: _colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
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
    bool showImages,
    int imageMaxWidth,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20.0 * (1.0 - animation.value)),
          child: FadeTransition(opacity: animation, child: child),
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
            color: _colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                if (article.imageUrl != null && showImages)
                  CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    width: imageMaxWidth.toDouble(),
                    fit: BoxFit.cover,
                    cacheManager: AppCacheManager(),
                    memCacheWidth: imageMaxWidth,
                    placeholder: (context, url) =>
                        Container(color: _colorScheme.surface),
                    errorWidget: (context, url, error) =>
                        Container(color: sourceColor.withValues(alpha: 0.1)),
                  )
                else
                  Container(color: sourceColor.withValues(alpha: 0.1)),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        _colorScheme.surface.withValues(alpha: 0.95),
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
                          color: _colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sourceName,
                          style: GoogleFonts.lexend(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _colorScheme.primary,
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
                          color: _colorScheme.onSurface.withValues(alpha: 0.7),
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
    return const SavedArticlesEmptyState();
  }
}
