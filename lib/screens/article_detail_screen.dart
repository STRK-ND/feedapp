import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// Article detail screen with proper HTML rendering and image display
class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({required this.article, super.key});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLoadingContent = false;
  bool _isLoadingImages = false;
  String? _fullContent;
  List<String> _articleImages = [];
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.article.isSaved;
    _initContent();
  }

  Future<void> _initContent() async {
    // Use existing content if available
    if (widget.article.fetchedFullContent != null) {
      setState(() {
        _fullContent = widget.article.fetchedFullContent;
      });
      return;
    }

    // Check if we have enough content already
    if (widget.article.fullContent.length < 200) {
      await _fetchFullContent();
    } else {
      setState(() {
        _fullContent = widget.article.fullContent;
      });
    }

    // Also try to get images
    await _fetchArticleImages();
  }

  Future<void> _fetchFullContent() async {
    setState(() => _isLoadingContent = true);

    try {
      final result = await ArticleContentService.fetchArticleContentWithImages(
        widget.article.link,
      );
      setState(() {
        _fullContent = result.text;
        _articleImages = result.images;
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

  Future<void> _fetchArticleImages() async {
    if (_articleImages.isNotEmpty) return;
    
    setState(() => _isLoadingImages = true);

    try {
      final result = await ArticleContentService.fetchArticleContentWithImages(
        widget.article.link,
      );
      if (mounted) {
        setState(() {
          _articleImages = result.images;
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingImages = false);
      }
    }
  }

  void _toggleSave() {
    setState(() {
      _isSaved = !_isSaved;
      widget.article.isSaved = _isSaved;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved ? 'Article saved' : 'Article removed from saved',
          style: GoogleFonts.dmSans(),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openInBrowser() async {
    final uri = Uri.parse(widget.article.link);
    if (await canLaunchUrl(uri)) {
      await AnalyticsService.logArticleLinkOpen(articleId: widget.article.id);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareArticle() {
    AnalyticsService.logArticleShare(articleId: widget.article.id);
    SharePlus.instance.share(ShareParams(
      text: '${widget.article.title}\n\n${widget.article.link}',
    ));
  }

  bool _showRatingSection() {
    return widget.article.author != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final source = RssFeedService.getSourceById(widget.article.sourceId) ?? 
                   RssFeedService.predefinedSources.first;
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.55;

    // Get all available images (from article + fetched)
    final allImages = <String>[];
    if (widget.article.imageUrl != null && widget.article.imageUrl!.isNotEmpty) {
      allImages.add(widget.article.imageUrl!);
    }
    allImages.addAll(_articleImages);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                children: [
                  // Main image or carousel
                  if (allImages.isNotEmpty)
                    _buildImageCarousel(allImages, imageHeight)
                  else
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: isDark ? const Color(0xFF1E1E2E) : AppColors.background,
                      child: Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(40),
              ),
            ),
                  ),
                  
                  // Top bar
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back button
                          Material(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(22),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  size: 24,
                                  color: isDark ? Colors.black : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          // Actions
                          Row(
                            children: [
                              // Save button
                              Material(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(22),
                                elevation: 2,
                                child: InkWell(
                                  onTap: _toggleSave,
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      _isSaved
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 24,
                                      color: _isSaved
                                          ? AppColors.error
                                          : (isDark ? Colors.black : AppColors.textPrimary),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Share button
                              Material(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(22),
                                elevation: 2,
                                child: InkWell(
                                  onTap: _shareArticle,
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.share_rounded,
                                      size: 24,
                                      color: isDark ? Colors.black : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Source badge
                  Positioned(
                    left: 20,
                    top: imageHeight - 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: source.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(source.icon, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            source.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
          
          // Content Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              transform: Matrix4.translationValues(0, -16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author and date
                  if (_showRatingSection()) ...[
                    Row(
                      children: [
                        if (widget.article.author != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: source.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: source.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.article.author!,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: source.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          Helpers.formatDate(widget.article.pubDate),
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Title
                  Text(
                    widget.article.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      height: 1.25,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Loading state
                  if (_isLoadingContent)
                    Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            color: source.color,
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading full article...',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_fullContent != null && _fullContent!.isNotEmpty)
                    // Render content with proper formatting
                    _buildContent(_fullContent!, isDark)
                  else
                    // Fallback to description
                    Text(
                      widget.article.description,
                      style: GoogleFonts.dmSans(
                        fontSize: 18,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                        height: 1.7,
                      ),
                    ),
                  
                  const SizedBox(height: 40),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        Icons.open_in_browser_rounded,
                        'Open in browser',
                        isDark ? Colors.white : AppColors.textPrimary,
                        _openInBrowser,
                        isDark,
                      ),
                      _buildActionButton(
                        Icons.share_rounded,
                        'Share',
                        isDark ? Colors.white : AppColors.textPrimary,
                        _shareArticle,
                        isDark,
                      ),
                      _buildActionButton(
                        Icons.bookmark_rounded,
                        _isSaved ? 'Saved' : 'Save',
                        _isSaved ? AppColors.error : (isDark ? Colors.white : AppColors.textPrimary),
                        _toggleSave,
                        isDark,
                      ),
                    ],
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

  /// Build image carousel for article
  Widget _buildImageCarousel(List<String> images, double height) {
    if (images.length == 1) {
      return CachedNetworkImage(
        imageUrl: images.first,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Icon(Icons.error),
        ),
      );
    }

    // Multiple images - show first with indicator
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              ),
            );
          },
        ),
        // Page indicators
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build properly formatted content
  Widget _buildContent(String content, bool isDark) {
    // Split content into paragraphs and render properly
    final paragraphs = content.split('\n\n').where((p) => p.trim().isNotEmpty).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((paragraph) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            paragraph.trim(),
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: isDark ? Colors.white : AppColors.textPrimary,
              height: 1.8,
              letterSpacing: 0.05,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
    bool isDark,
  ) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.1),
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}