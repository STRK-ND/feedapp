import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../di/service_locator.dart';
import '../models/article.dart';
import '../models/rss_source.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/stitch/stitch_widgets.dart';

/// Article detail screen with Stitch design
class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({required this.article, super.key});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLoadingContent = false;
  String? _fullContent;
  bool _isSaved = false;

  // Cached source to avoid recalculation on rebuild
  late final RssFeedService _rssFeedService;

  // Pre-bound callbacks to avoid recreation on each build
  late final VoidCallback _toggleSaveCallback;
  late final VoidCallback _shareArticleCallback;
  late final VoidCallback _backCallback;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.article.isSaved;
    _rssFeedService = getIt<RssFeedService>();

    // Initialize callbacks once in initState
    _toggleSaveCallback = _toggleSave;
    _shareArticleCallback = _shareArticle;
    _backCallback = () => Navigator.pop(context);

    _initContent();
  }

  Future<void> _initContent() async {
    if (widget.article.fetchedFullContent != null) {
      setState(() => _fullContent = widget.article.fetchedFullContent);
      return;
    }

    if (widget.article.fullContent.length < 200) {
      await _fetchFullContent();
    } else {
      setState(() => _fullContent = widget.article.fullContent);
    }
  }

  Future<void> _fetchFullContent() async {
    setState(() => _isLoadingContent = true);
    try {
      final result = await getIt<ArticleContentService>()
          .fetchArticleContentWithImages(widget.article.link);
      setState(() {
        _fullContent = result.text;
        _isLoadingContent = false;
      });
      widget.article.fetchedFullContent = result.text;
    } catch (e) {
      setState(() {
        _fullContent = widget.article.fullContent;
        _isLoadingContent = false;
      });
    }
  }

  void _toggleSave() {
    final newSavedState = !_isSaved;
    // Update state without triggering full rebuild - just update the specific field
    setState(() {
      _isSaved = newSavedState;
      widget.article.isSaved = newSavedState;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newSavedState ? 'Article saved' : 'Article removed',
          style: GoogleFonts.lexend(color: Colors.white),
        ),
        backgroundColor: AppColors.backgroundDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareArticle() {
    AnalyticsService.logArticleShare(articleId: widget.article.id);
    SharePlus.instance.share(
      ShareParams(text: '${widget.article.title}\n\n${widget.article.link}'),
    );
  }

  // Cached source computation - only recomputed if sourceId changes
  RssSource get _source {
    return _rssFeedService.getSourceById(widget.article.sourceId) ??
        RssFeedService.predefinedSources.first;
  }

  // Image height constant to avoid recalculation
  static const double _kImageHeightFactor = 0.5;
  static const double _kHorizontalPadding = 20.0;
  static const double _kContentPadding = 24.0;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final imageHeight = screenHeight * _kImageHeightFactor;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          // Hero Image Section
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: imageHeight,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Main image with Hero transition
                  Hero(
                    tag: getArticleHeroTag(widget.article.id),
                    child: widget.article.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.article.imageUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 800,
                            maxWidthDiskCache: 1200,
                          )
                        : Container(color: AppColors.primary10),
                  ),

                  // Gradient overlay (bottom to top for readability)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.backgroundDark,
                          AppColors.backgroundDark.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // Top bar with pre-bound callbacks
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildIconButton(
                            Icons.arrow_back_rounded,
                            _backCallback,
                          ),
                          Row(
                            children: [
                              _buildIconButton(
                                _isSaved ? Icons.favorite : Icons.favorite_border,
                                _toggleSaveCallback,
                                color: _isSaved ? AppColors.primary : Colors.white,
                              ),
                              const SizedBox(width: 12),
                              _buildIconButton(
                                Icons.share_outlined,
                                _shareArticleCallback,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Source badge
                  Positioned(
                    left: 24,
                    bottom: 24,
                    child: CategoryBadge(
                      category: _source.category,
                      backgroundColor: AppColors.primary,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(_kContentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author and date row
                  _buildMetadataRow(),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    widget.article.title,
                    style: GoogleFonts.lexend(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Content with const loading indicator
                  if (_isLoadingContent)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  else if (_fullContent != null && _fullContent!.isNotEmpty)
                    _buildContent(_fullContent!)
                  else
                    Text(
                      widget.article.description,
                      style: GoogleFonts.lexend(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.8),
                        height: 1.6,
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds metadata row (author/date) - extracted to prevent rebuilds of title/content
  Widget _buildMetadataRow() {
    final article = widget.article;
    final hasAuthor = article.author != null;

    return Row(
      children: [
        if (hasAuthor) ...[
          Icon(
            Icons.person_outline,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              article.author!,
              style: GoogleFonts.lexend(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
        ],
        Icon(
          Icons.access_time,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          Helpers.formatDate(article.pubDate),
          style: GoogleFonts.lexend(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 24),
      ),
    );
  }

  Widget _buildContent(String content) {
    final paragraphs = content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            paragraph.trim(),
            style: GoogleFonts.lexend(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.7,
            ),
          ),
        );
      }).toList(),
    );
  }
}
