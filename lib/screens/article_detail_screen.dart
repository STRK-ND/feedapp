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

  @override
  void initState() {
    super.initState();
    _isSaved = widget.article.isSaved;
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
      final result = await getIt<ArticleContentService>().fetchArticleContentWithImages(
        widget.article.link,
      );
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
    setState(() {
      _isSaved = !_isSaved;
      widget.article.isSaved = _isSaved;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved ? 'Article saved' : 'Article removed',
          style: GoogleFonts.lexend(color: Colors.white),
        ),
        backgroundColor: AppColors.backgroundDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    Share.share('${widget.article.title}\n\n${widget.article.link}');
  }

  @override
  Widget build(BuildContext context) {
    final source = getIt<RssFeedService>().getSourceById(widget.article.sourceId) ??
        getIt<RssFeedService>().predefinedSources.first;
    final screenHeight = MediaQuery.of(context).size.height;
    final imageHeight = screenHeight * 0.5;

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
                  // Main image
                  if (widget.article.imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: widget.article.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: AppColors.primary10),

                  // Gradient overlay (bottom to top for readability)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.backgroundDark,
                          AppColors.backgroundDark.withOpacity(0.4),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 1.0],
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
                          _buildIconButton(
                            Icons.arrow_back_rounded,
                            () => Navigator.pop(context),
                          ),
                          Row(
                            children: [
                              _buildIconButton(
                                _isSaved ? Icons.favorite : Icons.favorite_border,
                                _toggleSave,
                                color: _isSaved ? AppColors.primary : Colors.white,
                              ),
                              const SizedBox(width: 12),
                              _buildIconButton(
                                Icons.share_outlined,
                                _shareArticle,
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
                      category: source.name,
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
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author and date row
                  Row(
                    children: [
                      if (widget.article.author != null) ...[
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.article.author!,
                          style: GoogleFonts.lexend(
                            fontSize: 14,
                            color: AppColors.textSecondary,
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
                        Helpers.formatDate(widget.article.pubDate),
                        style: GoogleFonts.lexend(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
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

                  // Content
                  if (_isLoadingContent)
                    Center(
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
                        color: Colors.white.withOpacity(0.8),
                        height: 1.6,
                      ),
                    ),

                  const SizedBox(height: 40),

                  // Action buttons
                  _buildActionButtons(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color ?? Colors.white,
          size: 24,
        ),
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
              color: Colors.white.withOpacity(0.9),
              height: 1.7,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary5,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            Icons.open_in_browser_rounded,
            'Open',
            _openInBrowser,
          ),
          Container(
            width: 1,
            height: 30,
            color: AppColors.primary.withOpacity(0.2),
          ),
          _buildActionButton(
            Icons.share_outlined,
            'Share',
            _shareArticle,
          ),
          Container(
            width: 1,
            height: 30,
            color: AppColors.primary.withOpacity(0.2),
          ),
          _buildActionButton(
            _isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            _isSaved ? 'Saved' : 'Save',
            _toggleSave,
            isActive: _isSaved,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.primary : Colors.white.withOpacity(0.7),
            size: 24,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.lexend(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive ? AppColors.primary : Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}
