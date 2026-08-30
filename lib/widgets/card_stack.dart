import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/article.dart';
import '../services/cache_manager.dart';
import '../providers/settings_notifier.dart';
import '../utils/constants.dart' hide AppColors;
import '../utils/design_tokens.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sourceColor = _sourceColor(article.sourceColor);
    final cardColor = isDark ? AppColors.groundElev : colorScheme.surface;
    final ink = isDark ? AppColors.paperOnGround : AppColors.ink;
    final soft = isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;

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
            // Reskin: no amber shadow on a dark ground — it reads muddy.
            // A hairline border gives the card a quiet edge instead.
            color: cardColor,
            border: Border.all(color: ruleColor, width: 0.5),
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
                            color: isDark
                                ? const Color(
                                    0xFF000000,
                                  ).withValues(alpha: 0.55)
                                : null,
                            colorBlendMode: isDark ? BlendMode.darken : null,
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

                  // Content pinned to the bottom — editorial card on ground.
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Source row: color dot + uppercase mono source
                          // + mono dateline. Replaces the category badges —
                          // the source's own color IS the categorization.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: sourceColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    article.sourceName.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.6,
                                      color: ink.withValues(alpha: 0.85),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!article.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.curation,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Title — oversized Playfair w800, the card's voice.
                          Text(
                            article.title,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              height: 1.12,
                              letterSpacing: -0.6,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 14),

                          // Description
                          if (article.description.isNotEmpty)
                            Text(
                              article.description,
                              style: GoogleFonts.dmSans(
                                color: soft,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 20),

                          // Read cue — quiet mono, not an amber button. The
                          // card is already a tap target; a button is a restatement.
                          Text(
                            'READ  →',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: ink.withValues(alpha: 0.7),
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

/// Parse a source's brand color (hex) → Color, falling back to the amber
/// attention color when absent. Mirrors the helper in every row/card so
/// the source's own identity, not amber, color-tags the article.
Color _sourceColor(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.primary;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) return Color(int.parse('0xFF$cleaned'));
  return AppColors.primary;
}
