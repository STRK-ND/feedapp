import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/article.dart';
import '../services/cache_manager.dart';
import '../providers/settings_notifier.dart';
import '../utils/constants.dart';
import 'swipeable_card.dart';
import 'stitch/stitch_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _cardEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Prefetch initial images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchNextCardImage();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    if (mediaQuery.disableAnimations) {
      _cardEntranceController.value = 1.0;
    } else if (_cardEntranceController.value == 0) {
      _cardEntranceController.forward();
    }
  }

  void _prefetchNextCardImage() {
    // Prefetch image for the card at index 1 (next card after current front card)
    if (widget.articles.length > 1) {
      final nextArticle = widget.articles[1];
      if (nextArticle.imageUrl != null) {
        precacheImage(
          CachedNetworkImageProvider(nextArticle.imageUrl!),
          context,
        );
      }
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
      // Prefetch the new next card's image after a swipe
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefetchNextCardImage();
      });
    }
  }

  Widget _buildArticleCard(
    Article article,
    int index,
    bool isFront,
    bool showImages,
    int imageMaxWidth,
  ) {
    final sourceCategory = article.sourceCategory ?? 'Technology';
    final descText = article.description;
    final readTime = descText.isEmpty
        ? 1
        : (descText.split(RegExp(r'\s+')).length / 200).ceil().clamp(1, 999);
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label:
          'Article: ${article.title}. ${isFront ? 'Tap to read, swipe right to save, swipe left to dismiss.' : ''}',
      child: GestureDetector(
        onTap: () {
          if (isFront) {
            widget.onTap(index);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppCardStyles.cardRadius),
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppCardStyles.cardRadius),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image with Hero transition
                  Hero(
                    tag: getArticleHeroTag(article.id),
                    child: showImages && article.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: article.imageUrl!,
                            width: imageMaxWidth.toDouble(),
                            fit: BoxFit.cover,
                            cacheManager: AppCacheManager(),
                            memCacheWidth: imageMaxWidth,
                            placeholder: (context, url) => Container(
                              color: colorScheme.surfaceContainerHighest,
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Container(color: colorScheme.surfaceContainerHighest),
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
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
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
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppCardStyles.buttonRadius,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Read Full Story',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsNotifier>(
      builder: (context, settings, _) {
        if (widget.articles.isEmpty) {
          return widget.emptyState;
        }

        final article = widget.articles.first;
        final imageMaxWidth = settings.dataSaverMode ? 400 : 800;

        return SwipeableCard(
          key: ValueKey('card_${article.id}'),
          child: _buildArticleCard(
            article,
            0,
            true,
            settings.showImages,
            imageMaxWidth,
          ),
          onSwipeRight: () => widget.onSwipeRight(0),
          onSwipeLeft: () => widget.onSwipeLeft(0),
          onTap: () => widget.onTap(0),
        );
      },
    );
  }
}
