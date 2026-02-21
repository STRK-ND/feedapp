import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article.dart';
import '../models/rss_source.dart';
import '../services/cache_manager.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// Expanded article card bottom sheet/modal widget
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
      _fetchFullContent();
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
      final content = await ArticleContentService.fetchArticleContent(widget.article.link);
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

  @override
  Widget build(BuildContext context) {
    final source = RssFeedService.getSourceById(widget.article.sourceId) ??
        RssFeedService.predefinedSources.first;
    final sourceColor = source.color;

    return Dismissible(
      direction: DismissDirection.down,
      key: const Key('article_modal'),
      onDismissed: (_) => widget.onClose(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLarge,
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar with refined styling
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),

                // Header with refined layout
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Source badge
                          _buildSourceBadge(sourceColor, source),
                          // Action buttons
                          _buildActionButtons(sourceColor),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.borderSubtle,
                        AppColors.border.withValues(alpha: 0.5),
                        AppColors.borderSubtle,
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero image if available
                        if (widget.article.imageUrl != null) ...[
                          _buildHeroImage(),
                          const SizedBox(height: 20),
                        ],

                        // Metadata row
                        _buildMetadataRow(sourceColor),

                        const SizedBox(height: 16),

                        // Title with refined typography
                        Text(
                          widget.article.title,
                          style: GoogleFonts.lexend(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                            letterSpacing: -0.4,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Description (lead paragraph)
                        Text(
                          widget.article.description,
                          style: GoogleFonts.lexend(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            height: 1.6,
                            letterSpacing: 0.1,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Full content
                        if (_isLoadingContent)
                          _buildLoadingIndicator(sourceColor)
                        else if (_fullContent != null && _fullContent!.isNotEmpty)
                          Text(
                            _fullContent!,
                            style: GoogleFonts.lexend(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                              height: 1.7,
                              letterSpacing: 0.05,
                            ),
                          ),

                        const SizedBox(height: 100),
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
  }

  Widget _buildSourceBadge(Color sourceColor, RssSource source) {
    return Container(
      decoration: BoxDecoration(
        color: sourceColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(
          color: sourceColor.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 16, color: sourceColor),
          const SizedBox(width: 8),
          Text(
            source.name,
            style: GoogleFonts.lexend(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: sourceColor,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Color sourceColor) {
    return Row(
      children: [
        _buildIconButton(
          icon: Icons.open_in_new_rounded,
          onPressed: () async {
            final uri = Uri.parse(widget.article.link);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          color: AppColors.textSecondary,
          label: 'Open in browser',
        ),
        const SizedBox(width: 4),
        _buildIconButton(
          icon: Icons.share_rounded,
          onPressed: () {
            Share.share('${widget.article.title}\n\n${widget.article.link}');
          },
          color: AppColors.textSecondary,
          label: 'Share article',
        ),
        const SizedBox(width: 4),
        _buildIconButton(
          icon: widget.article.isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          onPressed: widget.onToggleSave,
          color: widget.article.isSaved ? AppColors.error : AppColors.textSecondary,
          label: widget.article.isSaved ? 'Saved' : 'Save',
        ),
        const SizedBox(width: 4),
        _buildIconButton(
          icon: Icons.close_rounded,
          onPressed: widget.onClose,
          color: AppColors.textTertiary,
          label: 'Close',
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required String label,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          ),
          child: Icon(
            icon,
            size: AppDimens.iconMedium,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.radiusXLarge),
      child: CachedNetworkImage(
        imageUrl: widget.article.imageUrl!,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheManager: AppCacheManager(),
        placeholder: (context, url) => Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimens.radiusXLarge),
          ),
          child: const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimens.radiusXLarge),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_outlined, size: 32, color: AppColors.textTertiary),
              const SizedBox(height: 8),
              Text(
                'Image unavailable',
                style: GoogleFonts.lexend(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(Color sourceColor) {
    final hasAuthor = widget.article.author != null;

    return Row(
      children: [
        if (hasAuthor) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline_rounded, size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  widget.article.author!,
                  style: GoogleFonts.lexend(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.access_time_rounded, size: 13, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                Helpers.formatDate(widget.article.pubDate),
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator(Color sourceColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sourceColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading full article...',
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
