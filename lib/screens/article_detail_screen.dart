import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

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

  @override
  void initState() {
    super.initState();
    _isSaved = widget.article.isSaved;
    _initContent();
  }

  Future<void> _initContent() async {
    if (widget.article.fetchedFullContent != null) {
      setState(() {
        _fullContent = widget.article.fetchedFullContent;
      });
      return;
    }

    if (widget.article.fullContent.length < 200) {
      await _fetchFullContent();
    } else {
      setState(() {
        _fullContent = widget.article.fullContent;
      });
    }
  }

  Future<void> _fetchFullContent() async {
    setState(() => _isLoadingContent = true);

    try {
      final content = await ArticleContentService.fetchArticleContent(
        widget.article.link,
      );
      setState(() {
        _fullContent = content;
        _isLoadingContent = false;
      });
      widget.article.fetchedFullContent = content;
    } catch (e) {
      setState(() {
        _fullContent = widget.article.fullContent;
        _isLoadingContent = false;
      });
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareArticle() {
    SharePlus.instance.share(ShareParams(text: '${widget.article.title}\n\n${widget.article.link}'));
  }

  bool _showRatingSection() {
    return widget.article.author != null || widget.article.pubDate != null;
  }

  @override
  Widget build(BuildContext context) {
    final source =
        RssFeedService.getSourceById(widget.article.sourceId) ??
        RssFeedService.predefinedSources.first;
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.6;

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: imageHeight,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(40),
                    ),
                    child: widget.article.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: widget.article.imageUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: AppColors.background,
                            child: const Icon(
                              Icons.article_outlined,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(40),
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 24,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),

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
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

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

          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              transform: Matrix4.translationValues(0, -16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        const Icon(
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

                  Text(
                    widget.article.title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    _fullContent ?? widget.article.description,
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 32),

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
                    Text(
                      _fullContent!,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        height: 1.8,
                        letterSpacing: 0.05,
                      ),
                    ),
                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(
                        Icons.open_in_browser_rounded,
                        'Open in browser',
                        AppColors.textPrimary,
                        _openInBrowser,
                      ),
                      _buildActionButton(
                        Icons.share_rounded,
                        'Share',
                        AppColors.textPrimary,
                        _shareArticle,
                      ),
                      _buildActionButton(
                        Icons.bookmark_rounded,
                        _isSaved ? 'Saved' : 'Save',
                        _isSaved ? AppColors.error : AppColors.textPrimary,
                        _toggleSave,
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

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
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
    final relatedArticles = RssFeedService.predefinedSources
        .where((s) => s.id != widget.article.sourceId)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More from this source',
          style: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: relatedArticles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final source = relatedArticles[index];
              return Container(
                width: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(source.icon, size: 20, color: source.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            source.name,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${source.category} →',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: source.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
