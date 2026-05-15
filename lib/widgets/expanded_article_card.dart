import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/cache_manager.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../providers/settings_notifier.dart';
import '../di/service_locator.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// Expanded article card bottom sheet/modal widget
/// Features: Glassmorphism, hero image fade-in transitions
class ExpandedArticleCard extends StatefulWidget {
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
  State<ExpandedArticleCard> createState() => _ExpandedArticleCardState();
}

class _ExpandedArticleCardState extends State<ExpandedArticleCard> {
  bool _isLoadingContent = false;
  String? _fullContent;

  @override
  void initState() {
    super.initState();
    _initContent();
  }

  Future<void> _initContent() async {
    // Check if we already have cached full content
    if (widget.article.fetchedFullContent != null) {
      setState(() {
        _fullContent = widget.article.fetchedFullContent;
      });
      return;
    }

    // Try to fetch full content only if RSS content is short
    if (widget.article.fullContent.length < 200) {
      // Call async method with proper error handling
      _fetchFullContent().catchError((error) {
        if (mounted) {
          setState(() {
            _fullContent = widget.article.fullContent;
          });
        }
      });
    } else {
      setState(() {
        _fullContent = widget.article.fullContent;
      });
    }
  }

  Future<void> _fetchFullContent() async {
    setState(() {
      _isLoadingContent = true;
    });

    try {
      final content = await getIt<ArticleContentService>().fetchArticleContent(
        widget.article.link,
      );
      setState(() {
        _fullContent = content;
        _isLoadingContent = false;
      });

      // Cache the fetched content in the article
      widget.article.fetchedFullContent = content;
    } catch (e) {
      setState(() {
        _fullContent = widget.article.fullContent;
        _isLoadingContent = false;
      });
    }
  }

  /// Hero image with fade-in transition animation
  Widget _buildFadeInImage(
    String imageUrl,
    double height,
    double borderRadius,
  String heroTag,
  ) {
  return Hero(
    tag: heroTag,
   child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheManager: AppCacheManager(),
        fadeInDuration: AppCardStyles.fadeInDuration,
        fadeOutDuration: AppCardStyles.fadeInDuration,
        placeholder: (context, url) =>
            _buildImagePlaceholder(height, borderRadius),
        errorWidget: (context, url, error) =>
            _buildImageError(height, borderRadius),
      ),
    ),
  );
  }

  Widget _buildImagePlaceholder(double height, double borderRadius) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildImageError(double height, double borderRadius) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          const Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source =
        getIt<RssFeedService>().getSourceById(widget.article.sourceId) ??
        RssFeedService.predefinedSources.first;
    final sourceColor = source.color;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<SettingsNotifier>(
      builder: (context, settings, _) {
        final showImages = settings.showImages;
        final imageMaxWidth = settings.imageMaxWidth.toDouble();

        Widget buildHeaderButton({
          required IconData icon,
          required VoidCallback onPressed,
          required Color color,
          required String label,
        }) {
          return Container(
            margin: const EdgeInsets.only(left: 4),
            child: Semantics(
              button: true,
              label: label,
              child: IconButton(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                color: color,
                padding: const EdgeInsets.all(12),
                style: IconButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.08),
                ),
              ),
            ),
          );
        }

        return Dismissible(
          direction: DismissDirection.down,
          key: const Key('article_modal'),
          onDismissed: (_) => widget.onClose(),
          child: DraggableScrollableSheet(
            initialChildSize: 1.0,
            minChildSize: 0.5,
            maxChildSize: 1.0,
            builder: (context, scrollController) {
              return Container(
                decoration: AppCardStyles.bottomSheetDecoration(colorScheme),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: AppCardStyles.chipDecoration(
                              sourceColor,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(source.icon, size: 14, color: sourceColor),
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
                          Row(
                            children: [
                              buildHeaderButton(
                                icon: Icons.open_in_new_rounded,
                                onPressed: () async {
                                  final uri = Uri.parse(widget.article.link);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                                color: sourceColor,
                                label: 'Open in browser',
                              ),
                              buildHeaderButton(
                                icon: Icons.share_rounded,
                                onPressed: () {
                                  SharePlus.instance.share(
                                    ShareParams(
                                      text:
                                          '${widget.article.title}\n\n${widget.article.link}',
                                    ),
                                  );
                                },
                                color: sourceColor,
                                label: 'Share article',
                              ),
                              buildHeaderButton(
                                icon: widget.article.isSaved
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                onPressed: widget.onToggleSave,
                                color: widget.article.isSaved
                                    ? colorScheme.error
                                    : sourceColor,
                                label: widget.article.isSaved
                                    ? 'Saved'
                                    : 'Save',
                              ),
                              buildHeaderButton(
                                icon: Icons.close_rounded,
                                onPressed: widget.onClose,
                                color: colorScheme.onSurfaceVariant,
                                label: 'Close',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showImages && widget.article.imageUrl != null)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: imageMaxWidth,
                                ),
                                child: _buildFadeInImage(
                                  widget.article.imageUrl!,
                                  220,
                                  AppCardStyles.imageRadius,
                                  getArticleHeroTag(widget.article.id),
                                ),
                              ),
                            if (showImages && widget.article.imageUrl != null)
                              const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  if (widget.article.author != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: AppCardStyles.chipDecoration(
                                        sourceColor,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.person_outline_rounded,
                                            size: 13,
                                            color: sourceColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            widget.article.author!,
                                            style: GoogleFonts.dmSans(
                                              fontSize: 12,
                                              color: sourceColor,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    Helpers.formatDate(widget.article.pubDate),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              widget.article.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                height: 1.35,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.article.description,
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                color: colorScheme.onSurface,
                                height: 1.7,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_isLoadingContent)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 40,
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              sourceColor,
                                            ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Loading full article...',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else if (_fullContent != null &&
                                _fullContent!.isNotEmpty)
                              Text(
                                _fullContent!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.8,
                                  letterSpacing: 0.05,
                                ),
                              ),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
