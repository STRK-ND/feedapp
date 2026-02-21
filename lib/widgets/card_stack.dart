import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../services/cache_manager.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'swipeable_card.dart';
import '../themes/tinder_theme.dart';

/// Tinder Card - Fun, vibrant design with photo-first layout
class _CardContent extends StatelessWidget {
  final Article article;
  final Color sourceColor;
  final String sourceName;
  final IconData sourceIcon;
  final bool hasImage;
  final bool isFront;

  const _CardContent({
    required this.article,
    required this.sourceColor,
    required this.sourceName,
    required this.sourceIcon,
    required this.hasImage,
    required this.isFront,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Stack(
          children: [
            // Hero image - taller section for visual impact
            if (hasImage)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: _buildTinderHeroImage(),
              )
            else
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: _buildTinderImagePlaceholder(),
              ),

            // Gradient overlay - only in bottom section where text appears
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      TinderTheme.bgDark.withValues(alpha: 0.7),
                      TinderTheme.bgDark.withValues(alpha: 0.95),
                    ],
                    stops: const [0.0, 0.3, 1.0],
                  ),
                ),
              ),
            ),

            // Content - positioned in bottom section
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Source badge with gradient
                    _buildTinderSourceBadge(),

                    const SizedBox(height: 12),

                    // Title - bold, large, white
                    Text(
                      article.title,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: TinderTheme.textPrimary,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Description - smaller, grey
                    if (article.description.isNotEmpty)
                      Text(
                        article.description,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: TinderTheme.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 14),

                    // Metadata - time and author at bottom
                    _buildTinderMetadata(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hero image scaled to fit card
  Widget _buildTinderHeroImage() {
    return CachedNetworkImage(
      imageUrl: article.imageUrl!,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      cacheManager: AppCacheManager(),
      placeholder: (context, url) => _buildTinderImagePlaceholder(),
      errorWidget: (context, url, error) => _buildTinderImagePlaceholder(),
    );
  }

  /// Gradient-styled placeholder when image fails to load
  Widget _buildTinderImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: TinderTheme.backgroundGradient,
      ),
      child: Center(
        child: Icon(
          Icons.photo_size_select_large_outlined,
          size: 64,
          color: TinderTheme.textTertiary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// Gradient source badge with playful styling
  Widget _buildTinderSourceBadge() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            sourceColor.withValues(alpha: 0.7),
            sourceColor.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: sourceColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sourceIcon,
            size: 16,
            color: TinderTheme.textPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            sourceName,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: TinderTheme.textPrimary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom metadata row with time and author
  Widget _buildTinderMetadata() {
    return Row(
      children: [
        // Time icon
        Icon(
          Icons.access_time_rounded,
          size: 14,
          color: TinderTheme.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          Helpers.formatTimeAgo(article.pubDate),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TinderTheme.textSecondary,
          ),
        ),

        const SizedBox(width: 16),

        // Author if available
        if (article.author != null) ...[
          Icon(
            Icons.person_rounded,
            size: 14,
            color: TinderTheme.textTertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              article.author!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TinderTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],

        // Unread indicator dot
        const Spacer(),
        if (!article.isRead)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: sourceColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: sourceColor.withValues(alpha: 0.6),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

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
    // Use reduced duration if user prefers reduced motion
    final duration = Helpers.getAnimationDuration(
      const Duration(milliseconds: 500),
      reducedDuration: const Duration(milliseconds: 150),
    );
    _cardEntranceController = AnimationController(
      vsync: this,
      duration: duration,
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
    final hasImage = article.imageUrl != null;

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
      child: _CardContent(
        article: article,
        sourceColor: sourceColor,
        sourceName: source.name,
        sourceIcon: source.icon,
        hasImage: hasImage,
        isFront: isFront,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) {
      return widget.emptyState;
    }

    final visibleArticles = widget.articles.take(3).toList();

    return RepaintBoundary(
      child: Stack(
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
      ),
    );
  }
}
