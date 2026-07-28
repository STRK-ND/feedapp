import 'dart:async';
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
import '../utils/constants.dart' hide AppColors;
import '../utils/design_tokens.dart';
import '../utils/helpers.dart';
import '../utils/reader_theme.dart';
import 'reader_controls.dart';

/// Expanded article card bottom sheet/modal widget
/// Features: Glassmorphism, hero image fade-in transitions,
/// reader-mode controls (theme swatches + Aa panel)
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

  // Reader preferences are now sourced from the SettingsNotifier (which
  // is the single owner). Local copies are kept only as a brief in-
  // frame cache so we don't `read` on every widget rebuild; the
  // Consumer below triggers a rebuild on every notify.
  ReaderTheme _readerTheme = ReaderTheme.defaultTheme;
  double _fontSize = 16;
  double _lineHeight = 1.6;
  bool _widenMeasure = false;
  bool _monoDatelines = true;
  String _bodyFont = 'dm';

  @override
  void initState() {
    super.initState();
    _initContent();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final notifier = context.read<SettingsNotifier>();
    if (!mounted) return;
    setState(() {
      _readerTheme = notifier.readerTheme;
      _fontSize = notifier.fontSize;
      _lineHeight = notifier.lineHeight;
      _widenMeasure = notifier.widenMeasure;
      _bodyFont = notifier.bodyFont;
      _monoDatelines = notifier.monoDatelines;
    });
  }

  Future<void> _persistTheme(ReaderTheme t) async {
    final notifier = context.read<SettingsNotifier>();
    if (isReaderThemeLocked(t, notifier.isPro)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${t.label} is a Pro theme — Go Pro to unlock'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    await notifier.setReaderTheme(t);
    if (mounted) setState(() => _readerTheme = t);
  }

  Future<void> _persistFontSize(double v) async {
    await context.read<SettingsNotifier>().setFontSize(v);
    if (mounted) setState(() => _fontSize = v);
  }

  Future<void> _persistLineHeight(double v) async {
    await context.read<SettingsNotifier>().setLineHeight(v);
    if (mounted) setState(() => _lineHeight = v);
  }

  Future<void> _persistWiden(bool v) async {
    await context.read<SettingsNotifier>().setWidenMeasure(v);
    if (mounted) setState(() => _widenMeasure = v);
  }

  Future<void> _persistBodyFont(String v) async {
    await context.read<SettingsNotifier>().setBodyFont(v);
    if (mounted) setState(() => _bodyFont = v);
  }

  Future<void> _initContent() async {
    // Check if we already have cached full content
    if (widget.article.fetchedFullContent != null) {
      if (mounted) {
        setState(() {
          _fullContent = widget.article.fetchedFullContent;
        });
      }
      return;
    }

    // Try to fetch full content only if RSS content is short
    if (widget.article.fullContent.length < 200) {
      await _fetchFullContent();
    } else {
      if (mounted) {
        setState(() {
          _fullContent = widget.article.fullContent;
        });
      }
    }
  }

  Future<void> _fetchFullContent() async {
    if (!mounted) return;
    setState(() {
      _isLoadingContent = true;
    });

    try {
      final content = await getIt<ArticleContentService>().fetchArticleContent(
        widget.article.link,
      );
      if (!mounted) return;
      setState(() {
        _fullContent = content;
        _isLoadingContent = false;
      });

      // Cache the fetched content in the article
      widget.article.fetchedFullContent = content;
    } catch (e) {
      if (!mounted) return;
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
  ) {
    return ClipRRect(
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
    );
  }

  Widget _buildImagePlaceholder(double height, double borderRadius) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildImageError(double height, double borderRadius) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
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
        // Mirror from the notifier so any external change (from Settings)
        // propagates live. The local setters above also call setX (which
        // notifies) so the Consumer will rebuild after our own writes
        // too — but using the notifier values directly avoids the
        // single-frame lag.
        _readerTheme = settings.readerTheme;
        _fontSize = settings.fontSize;
        _lineHeight = settings.lineHeight;
        _widenMeasure = settings.widenMeasure;
        _bodyFont = settings.bodyFont;
        _monoDatelines = settings.monoDatelines;

        final palette = ReaderPalette.forTheme(
          theme: _readerTheme,
          appBrightness: Theme.of(context).brightness,
        );

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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppCardStyles.buttonRadius,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Dismissible(
          direction: DismissDirection.vertical,
          key: Key('article_modal_${widget.article.id}'),
          onDismissed: (_) => widget.onClose(),
          child: DraggableScrollableSheet(
            initialChildSize: 1.0,
            minChildSize: 0.5,
            maxChildSize: 1.0,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: palette.ground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      blurRadius: 32,
                      offset: const Offset(0, -16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.rule,
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
                          Flexible(
                            child: Container(
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
                                  Flexible(
                                    child: Text(
                                      source.name,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: sourceColor,
                                        letterSpacing: 0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
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
                                color: palette.soft,
                                label: 'Close',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: palette.rule),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _widenMeasure ? 720 : 960,
                            ),
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
                                    color: palette.soft,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    Helpers.formatDate(
                                      widget.article.pubDate,
                                    ),
                                    style: (_monoDatelines
                                            ? GoogleFonts.jetBrainsMono
                                            : GoogleFonts.dmSans)(
                                        fontSize: 13,
                                        color: palette.soft,
                                        letterSpacing: 0.1,
                                      ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s2),
                            // Reader-mode controls: theme swatches + Aa.
                            ReaderControls(
                              currentTheme: _readerTheme,
                              fontSize: _fontSize,
                              lineHeight: _lineHeight,
                              widenMeasure: _widenMeasure,
                              bodyFont: _bodyFont,
                              isPro: settings.isPro,
                              onTheme: _persistTheme,
                              onFontSize: _persistFontSize,
                              onLineHeight: _persistLineHeight,
                              onWidenMeasure: _persistWiden,
                              onBodyFont: _persistBodyFont,
                              onLockedTheme: (t) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${t.label} is a Pro theme — Go Pro to unlock',
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.s5),
                            Text(
                              widget.article.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                                height: 1.35,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.article.description,
                              style: _bodyStyle().copyWith(
                                fontSize: _fontSize,
                                color: palette.text,
                                height: _lineHeight,
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
                                          color: palette.soft,
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
                                style: _bodyStyle().copyWith(
                                  fontSize: _fontSize - 1,
                                  color: palette.soft,
                                  height: _lineHeight + 0.1,
                                  letterSpacing: 0.05,
                                ),
                              ),
                              const SizedBox(height: 120),
                              ],
                            ),
                          ),
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

  /// Body font for the article text. 'dm' → DM Sans; 'lora' → Lora.
  TextStyle _bodyStyle() {
    if (_bodyFont == 'lora') {
      return GoogleFonts.lora(fontWeight: FontWeight.w400);
    }
    return GoogleFonts.dmSans(fontWeight: FontWeight.w400);
  }
}
