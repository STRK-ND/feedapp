import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';

void main() {
  runApp(const RssReaderApp());
}

class RssReaderApp extends StatelessWidget {
  const RssReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curated Feeds',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.dmSansTextTheme().copyWith(
          headlineLarge: GoogleFonts.playfairDisplay(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: _AppColors.textPrimary,
          ),
          headlineMedium: GoogleFonts.playfairDisplay(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: _AppColors.textPrimary,
          ),
          headlineSmall: GoogleFonts.playfairDisplay(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: _AppColors.textPrimary,
          ),
          titleLarge: GoogleFonts.playfairDisplay(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: _AppColors.textPrimary,
          ),
          titleMedium: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            color: _AppColors.textPrimary,
          ),
          bodyLarge: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
            color: _AppColors.textPrimary,
            height: 1.6,
          ),
          bodyMedium: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
            color: _AppColors.textPrimary,
            height: 1.5,
          ),
          labelLarge: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: _AppColors.textPrimary,
          ),
        ),
      ),
      home: const RssFeedScreen(),
    );
  }
}

class _AppColors {
  static const Color primary = Color(0xFF1A1B4D); // Deep midnight blue
  static const Color accent = Color(0xFFC9A962); // Muted gold
  static const Color background = Color(0xFFF8F7F4); // Cream white
  static const Color surface = Color(0xFFFFFFFF); // Pure white
  static const Color textPrimary = Color(0xFF1A1B2E); // Deep charcoal
  static const Color textSecondary = Color(0xFF6B7280); // Muted gray
  static const Color textTertiary = Color(0xFF9CA3AF); // Light gray
  static const Color divider = Color(0xFFE5E7EB); // Subtle border
  static const Color error = Color(0xFFDC3640); // Refined red
  static const Color success = Color(0xFF057A55); // Deep emerald

  static const Color techPrimary = Color(0xFF3B82F6);
  static const Color techSecondary = Color(0xFF60A5FA);
  static const Color newsPrimary = Color(0xFFDC2626);
  static const Color newsSecondary = Color(0xFFEF4444);
  static const Color sciencePrimary = Color(0xFF0891B2);
  static const Color scienceSecondary = Color(0xFF22D3EE);
  static const Color sportsPrimary = Color(0xFF059669);
  static const Color sportsSecondary = Color(0xFF34D399);
  static const Color entertainmentPrimary = Color(0xFF7C3AED);
  static const Color entertainmentSecondary = Color(0xFFA78BFA);
}

// Data Models
class RssSource {
  final String id;
  final String name;
  final String url;
  final String category;
  final Color color;
  final IconData icon;

  RssSource({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.color,
    required this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'category': category,
      'color': color.toARGB32(),
      'icon': icon.codePoint,
    };
  }

  factory RssSource.fromJson(Map<String, dynamic> json) {
    return RssSource(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      category: json['category'] as String,
      color: Color(json['color'] as int),
      icon: IconData(json['icon'] as int, fontFamily: 'MaterialIcons'),
    );
  }
}

class Article {
  final String id;
  final String title;
  final String description;
  final String fullContent;
  final String link;
  final String sourceId;
  final String sourceName;
  final DateTime pubDate;
  final String? author;
  final String? imageUrl;
  bool isRead;
  bool isSaved;

  Article({
    required this.id,
    required this.title,
    required this.description,
    required this.fullContent,
    required this.link,
    required this.sourceId,
    required this.sourceName,
    required this.pubDate,
    this.author,
    this.imageUrl,
    this.isRead = false,
    this.isSaved = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'fullContent': fullContent,
      'link': link,
      'sourceId': sourceId,
      'sourceName': sourceName,
      'pubDate': pubDate.millisecondsSinceEpoch,
      'author': author,
      'imageUrl': imageUrl,
      'isRead': isRead,
      'isSaved': isSaved,
    };
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      fullContent: json['fullContent'] as String,
      link: json['link'] as String,
      sourceId: json['sourceId'] as String,
      sourceName: json['sourceName'] as String,
      pubDate: DateTime.fromMillisecondsSinceEpoch(json['pubDate'] as int),
      author: json['author'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
    );
  }
}

// RSS Feed Service
class RssFeedService {
  static final List<RssSource> predefinedSources = [
    // Tech
    RssSource(
      id: 'techcrunch',
      name: 'TechCrunch',
      url: 'https://techcrunch.com/feed/',
      category: 'Tech',
      color: _AppColors.techPrimary,
      icon: Icons.computer,
    ),
    RssSource(
      id: 'verge',
      name: 'The Verge',
      url: 'https://www.theverge.com/rss/index.xml',
      category: 'Tech',
      color: _AppColors.techSecondary,
      icon: Icons.devices,
    ),
    RssSource(
      id: 'hackernews',
      name: 'Hacker News',
      url: 'https://hnrss.org/frontpage',
      category: 'Tech',
      color: const Color(0xFF8B5CF6),
      icon: Icons.code,
    ),

    // News
    RssSource(
      id: 'bbc',
      name: 'BBC World',
      url: 'http://feeds.bbci.co.uk/news/rss.xml',
      category: 'News',
      color: _AppColors.newsPrimary,
      icon: Icons.public,
    ),
    RssSource(
      id: 'cnn',
      name: 'CNN Top Stories',
      url: 'http://rss.cnn.com/rss/cnn_topstories.rss',
      category: 'News',
      color: _AppColors.newsSecondary,
      icon: Icons.article_rounded,
    ),

    // Science
    RssSource(
      id: 'sciencedaily',
      name: 'Science Daily',
      url: 'https://www.sciencedaily.com/rss/top.xml',
      category: 'Science',
      color: _AppColors.sciencePrimary,
      icon: Icons.science_rounded,
    ),

    // Sports
    RssSource(
      id: 'espn',
      name: 'ESPN Top',
      url: 'https://www.espn.com/espn/rss/news',
      category: 'Sports',
      color: _AppColors.sportsPrimary,
      icon: Icons.sports,
    ),

    // Entertainment
    RssSource(
      id: 'variety',
      name: 'Variety',
      url: 'https://variety.com/feed/',
      category: 'Entertainment',
      color: _AppColors.entertainmentPrimary,
      icon: Icons.theaters_rounded,
    ),
  ];

  static Future<List<Article>> fetchArticles(RssSource source) async {
    try {
      final response = await http.get(Uri.parse(source.url)).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode == 200) {
        return _parseRssXml(response.body, source);
      }
      debugPrint('HTTP ${response.statusCode} for ${source.name}');
      return [];
    } catch (e) {
      debugPrint('Error fetching ${source.name}: $e');
      return [];
    }
  }

  static List<Article> _parseRssXml(String xmlString, RssSource source) {
    final document = XmlDocument.parse(xmlString);
    final articles = <Article>[];

    final items = document.findAllElements('item').take(20);

    for (final item in items) {
      try {
        final titleElement = item.findElements('title').firstOrNull;
        final linkElement = item.findElements('link').firstOrNull;
        final descriptionElement = item.findElements('description').firstOrNull;
        final pubDateElement = item.findElements('pubDate').firstOrNull;
        final authorElement = item.findElements('author').firstOrNull
            ?? item.findElements('dc:creator').firstOrNull;

        // Image extraction - try multiple common fields
        String? imageUrl;

        // Method 1: enclosure element (most common)
        final enclosureElement = item.findElements('enclosure').firstOrNull;
        if (enclosureElement != null) {
          final url = enclosureElement.getAttribute('url');
          if (url != null) {
            imageUrl = url;
          }
        }

        // Method 2: media:content element
        if (imageUrl == null) {
          final mediaElement = item.findElements('media:content').firstOrNull;
          if (mediaElement != null) {
            final url = mediaElement.getAttribute('url');
            if (url != null) {
              imageUrl = url;
            }
          }
        }

        // Method 2.5: media:thumbnail element
        if (imageUrl == null) {
          final thumbnailElement = item.findElements('media:thumbnail').firstOrNull;
          if (thumbnailElement != null) {
            final url = thumbnailElement.getAttribute('url');
            if (url != null) {
              imageUrl = url;
            }
          }
        }

        // Method 3: description HTML img tags
        if (imageUrl == null && descriptionElement != null) {
          final descriptionText = descriptionElement.innerText;
          if (descriptionText.isNotEmpty) {
            final imgMatches = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', multiLine: true)
                .allMatches(descriptionText)
                .map((m) => m.group(1))
                .whereType<String>();
            if (imgMatches.isNotEmpty) {
              imageUrl = imgMatches.first;
            }
          }
        }

        // Method 4: Try content:encoded for embedded HTML images
        if (imageUrl == null) {
          final contentElement = item.findElements('content:encoded').firstOrNull;
          if (contentElement != null) {
            final contentText = contentElement.innerText;
            if (contentText.isNotEmpty) {
              final imgMatches = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', multiLine: true)
                  .allMatches(contentText)
                  .map((m) => m.group(1))
                  .whereType<String>();
              if (imgMatches.isNotEmpty) {
                imageUrl = imgMatches.first;
              }
            }
          }
        }

        // Method 5: Try to extract ANY URL from description as fallback (be lenient)
        if (imageUrl == null && descriptionElement != null) {
          final descriptionText = descriptionElement.innerText;
          if (descriptionText.isNotEmpty && descriptionText.contains('http')) {
            // Find all URLs in the content
            final urlMatches = RegExp(r'https?://\S+', multiLine: true)
                .allMatches(descriptionText)
                .map((m) => m.group(0)!);

            // Pick the first URL that doesn't look like the main article link
            for (final url in urlMatches) {
              // Skip if it's the main article link (we already have that)
              if (linkElement != null && url == linkElement.innerText) continue;

              // Just accept it - be very lenient to catch any images
              imageUrl = url;
              break;
            }
          }
        }

        // If still no image, try extracting from the full content/encoded
        if (imageUrl == null) {
          final contentElement = item.findElements('content:encoded').firstOrNull;
          if (contentElement != null) {
            final contentText = contentElement.innerText;
            if (contentText.isNotEmpty && contentText.contains('http')) {
              final urlMatches = RegExp(r'https?://\S+', multiLine: true)
                  .allMatches(contentText)
                  .map((m) => m.group(0)!);
              if (urlMatches.isNotEmpty) {
                // Pick a URL that doesn't look like the article link
                for (final url in urlMatches) {
                  if (linkElement != null && url == linkElement.innerText) continue;
                  imageUrl = url;
                  break;
                }
              }
            }
          }
        }

        if (titleElement == null || linkElement == null) continue;

        String description = '';
        if (descriptionElement != null) {
          description = _stripHtmlTags(descriptionElement.innerText);
        }

        String fullContent = '';
        final contentElement = item.findElements('content:encoded').firstOrNull;
        if (contentElement != null) {
          fullContent = contentElement.innerText;
        } else {
          fullContent = description;
        }

        DateTime pubDate = DateTime.now();
        if (pubDateElement != null) {
          pubDate = _parseDate(pubDateElement.innerText);
        }

        final articleId = linkElement.innerText.hashCode.toString();

        articles.add(Article(
          id: articleId,
          title: _stripHtmlTags(titleElement.innerText).trim(),
          description: description.length > 150
              ? '${description.substring(0, 150)}...'
              : description,
          fullContent: fullContent,
          link: linkElement.innerText,
          sourceId: source.id,
          sourceName: source.name,
          pubDate: pubDate,
          author: authorElement?.innerText.trim(),
          imageUrl: imageUrl,
        ));
      } catch (e) {
        debugPrint('Error parsing item: $e');
      }
    }

    return articles;
  }

  static bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;

    final lowerUrl = url.toLowerCase();

    // Check for common image file extensions
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.avif', '.heic', '.ico', '.tif', '.tiff'];
    for (final ext in validExtensions) {
      if (lowerUrl.contains(ext)) return true;
    }

    // Check for common image CDN patterns (these often don't have explicit extensions)
    final imagePatterns = [
      // Cloudinary
      'clouddn.com',
      'cloudinary.com',
      'res.cloudinary',
      // Image services
      'images.unsplash.com',
      'cdn.pixabay.com',
      'imgur.com',
      'i.imgur.com',
      'cdn-images-1.medium.com',
      'miro.medium.com',
      'static.wixstatic.com',
      'images.unsplash.com',
      'pbs.twimg.com', // Twitter images
      'abs-0.twimg.com', // Twitter images
      // Image CDNs commonly used
      'cdn.',
      'images.',
      'static.',
      'assets.',
      'img.',
      'media.',
      'thumbs.',
      'thumbnail.',
      'preview.',
    ];

    for (final pattern in imagePatterns) {
      if (lowerUrl.contains(pattern)) return true;
    }

    // Accept URLs that look like they might be images based on parameters
    if (lowerUrl.contains('image') || lowerUrl.contains('photo') || lowerUrl.contains('picture')) {
      return true;
    }

    // Accept URLs that have dimensions (often image thumbnails)
    if (lowerUrl.contains('&width=') || lowerUrl.contains('&height=') ||
        lowerUrl.contains('?width=') || lowerUrl.contains('?height=') ||
        lowerUrl.contains('w=') || lowerUrl.contains('h=')) {
      return true;
    }

    // Accept URLs that look like content delivery
    if (lowerUrl.contains('content') && (lowerUrl.contains('cdn') || lowerUrl.contains('media'))) {
      return true;
    }

    return false;
  }

  static String _stripHtmlTags(String htmlString) {
    final regex = RegExp(r'<[^>]*>', multiLine: true);
    return htmlString.replaceAll(regex, '').trim();
  }

  static DateTime _parseDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      try {
        return _parseCustomDate(dateString);
      } catch (e2) {
        return DateTime.now();
      }
    }
  }

  static DateTime _parseCustomDate(String dateStr) {
    final months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
    };

    final parts = dateStr.split(' ');
    if (parts.length >= 5) {
      try {
        final day = int.parse(parts[1].replaceAll(',', ''));
        final month = months[parts[2]];
        final year = int.parse(parts[3]);
        return DateTime(year, month ?? 1, day);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static Future<List<Article>> fetchAllArticles() async {
    final allArticles = <Article>[];

    // Fetch all sources in parallel for speed
    final results = await Future.wait(
      predefinedSources.map((source) => fetchArticles(source)),
      eagerError: true, // Continue even if some sources fail
    );

    // Flatten results
    for (final sourceArticles in results) {
      allArticles.addAll(sourceArticles);
    }

    // Sort by publication date (newest first)
    allArticles.sort((a, b) => b.pubDate.compareTo(a.pubDate));

    return allArticles;
  }
}

enum ViewMode { cards, list }

class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final VoidCallback onTap;
  final double swipeThreshold;

  const SwipeableCard({
    super.key,
    required this.child,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onTap,
    this.swipeThreshold = 150.0,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  final double _rotationFactor = 0.015;
  late final AnimationController _controller;

  Offset _position = Offset.zero;
  double _rotation = 0.0;
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isAnimatingOut) {
        final direction = _position.dx > 0 ? 'right' : 'left';
        if (direction == 'right') {
          widget.onSwipeRight();
        } else {
          widget.onSwipeLeft();
        }
        setState(() {
          _position = Offset.zero;
          _rotation = 0.0;
          _isAnimatingOut = false;
        });
      } else if (status == AnimationStatus.completed) {
        setState(() {
          _position = Offset.zero;
          _rotation = 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isAnimatingOut) return;
    setState(() {
      _position += details.delta;
      _rotation = _position.dx * _rotationFactor;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isAnimatingOut) return;

    if (_position.dx.abs() > widget.swipeThreshold) {
      _animateOut();
    } else {
      _animateBack();
    }

    if (_position.dy.abs() > widget.swipeThreshold) {
      _animateBack();
    }
  }

  void _animateOut() {
    setState(() {
      _isAnimatingOut = true;
    });

    _controller.reset();
    _controller.forward().then((_) {
      final direction = _position.dx > 0 ? 'right' : 'left';
      if (direction == 'right') {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
      setState(() {
        _position = Offset.zero;
        _rotation = 0.0;
        _isAnimatingOut = false;
      });
    });
  }

  void _animateBack() {
    final animation = Tween<Offset>(
      begin: _position,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    final rotationAnimation = Tween<double>(
      begin: _rotation,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.reset();
    _controller.forward();

    animation.addListener(() {
      if (mounted) {
        setState(() {
          _position = animation.value;
          _rotation = rotationAnimation.value;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTap: widget.onTap,
      child: Stack(
        children: [
          // Left swipe background (dismiss)
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                color: _AppColors.textSecondary
                    .withValues(alpha:_position.dx < 0 ? _position.dx.abs() / 600 : 0),
              );
            },
          ),

          // Right swipe background (save)
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                color: _AppColors.success
                    .withValues(alpha:_position.dx > 0 ? (_position.dx / 600) * 0.15 : 0),
              );
            },
          ),

          if (_position.dx < -50)
            Positioned(
              left: 40,
              top: 60,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  Icons.close_rounded,
                  size: 80,
                  color: _AppColors.textSecondary.withValues(alpha:
                    _position.dx.abs().clamp(50.0, 500.0) / 500.0,
                  ),
                ),
              ),
            ),

          if (_position.dx > 50)
            Positioned(
              right: 40,
              top: 60,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 80,
                  color: _AppColors.accent.withValues(alpha:
                    _position.dx.clamp(50.0, 500.0) / 500.0,
                  ),
                ),
              ),
            ),

          Positioned.fill(
            child: Transform.translate(
              offset: _position,
              child: Transform.rotate(
                angle: _rotation,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CardStack extends StatefulWidget {
  final List<Article> articles;
  final Function(int) onSwipeRight;
  final Function(int) onSwipeLeft;
  final Function(int) onTap;
  final Widget emptyState;
  final bool isFilterActive;

  const CardStack({
    super.key,
    required this.articles,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onTap,
    required this.emptyState,
    required this.isFilterActive,
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
    _cardEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardEntranceController.forward();
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
      _cardEntranceController.forward();
    }
  }

  Widget _buildArticleCard(Article article, int index, bool isFront) {
    final source = RssFeedService.predefinedSources.firstWhere(
      (s) => s.id == article.sourceId,
      orElse: () => RssFeedService.predefinedSources[0],
    );
    final sourceColor = source.color;

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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: _AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: sourceColor.withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 20),
              spreadRadius: -8,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _AppColors.divider.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source badge
                Container(
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        source.icon,
                        size: 14,
                        color: sourceColor,
                      ),
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

                const SizedBox(height: 24),

                // Hero image if available
                if (article.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: _AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            size: 32,
                            color: _AppColors.textTertiary,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: _AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 32,
                            color: _AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (article.imageUrl != null)
                  const SizedBox(height: 24),

                // Article title
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      article.title,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: _AppColors.textPrimary,
                        height: 1.35,
                        letterSpacing: -0.3,
                      ),
                      textAlign: TextAlign.left,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Description snippet
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    article.description,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: _AppColors.textSecondary,
                      height: 1.5,
                      letterSpacing: 0.1,
                    ),
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 20),

                // Publication time
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _AppColors.divider.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 14,
                        color: _AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(article.pubDate),
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: _AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) {
      return widget.emptyState;
    }

    final visibleArticles = widget.articles.take(3).toList();

    return Stack(
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
                widget.onSwipeRight(widget.articles.indexOf(widget.articles[i]));
              },
              onSwipeLeft: () {
                widget.onSwipeLeft(widget.articles.indexOf(widget.articles[i]));
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
    );
  }
}

// Expanded Article View Modal
class ExpandedArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onClose;
  final VoidCallback onToggleSave;

  const ExpandedArticleCard({
    super.key,
    required this.article,
    required this.onClose,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final source = RssFeedService.predefinedSources.firstWhere(
      (s) => s.id == article.sourceId,
      orElse: () => RssFeedService.predefinedSources[0],
    );
    final sourceColor = source.color;

    return Dismissible(
      direction: DismissDirection.down,
      key: const Key('article_modal'),
      onDismissed: (_) => onClose(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: _AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, -20),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
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
                          _buildHeaderButton(
                            icon: Icons.open_in_new_rounded,
                            onPressed: () async {
                              final uri = Uri.parse(article.link);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            color: sourceColor,
                          ),
                          _buildHeaderButton(
                            icon: Icons.share_rounded,
                            onPressed: () {
                              Share.share('${article.title}\n\n${article.link}');
                            },
                            color: sourceColor,
                          ),
                          _buildHeaderButton(
                            icon: article.isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            onPressed: onToggleSave,
                            color: article.isSaved ? _AppColors.error : sourceColor,
                          ),
                          _buildHeaderButton(
                            icon: Icons.close_rounded,
                            onPressed: onClose,
                            color: _AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image if available
                        if (article.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: article.imageUrl!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  color: _AppColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: 220,
                                decoration: BoxDecoration(
                                  color: _AppColors.background,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 20),
                                    Icon(
                                      Icons.broken_image_outlined,
                                      size: 32,
                                      color: _AppColors.textTertiary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image unavailable',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: _AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Author and date
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            children: [
                              if (article.author != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: sourceColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person_outline_rounded, size: 13, color: sourceColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        article.author!,
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
                              Icon(Icons.access_time_rounded, size: 14, color: _AppColors.textTertiary),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(article.pubDate),
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: _AppColors.textSecondary,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Title
                        Text(
                          article.title,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: _AppColors.textPrimary,
                            height: 1.35,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Description
                        Text(
                          article.description,
                          style: GoogleFonts.dmSans(
                            fontSize: 16,
                            color: _AppColors.textPrimary,
                            height: 1.7,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Full content with HTML stripped
                        Text(
                          _stripHtmlTags(article.fullContent),
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            color: _AppColors.textSecondary,
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
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: color,
        padding: const EdgeInsets.all(8),
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.08),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _stripHtmlTags(String html) {
    final regex = RegExp(r'<[^>]*>', multiLine: true);
    return html.replaceAll(regex, '').trim();
  }
}

// Main Screen
class RssFeedScreen extends StatefulWidget {
  const RssFeedScreen({super.key});

  @override
  State<RssFeedScreen> createState() => _RssFeedScreenState();
}

class _RssFeedScreenState extends State<RssFeedScreen>
    with TickerProviderStateMixin {
  List<Article> _articles = [];
  List<Article> _savedArticles = [];
  List<Article> _displayedArticles = [];
  String _selectedFilter = 'All';
  ViewMode _viewMode = ViewMode.cards;
  int _selectedTab = 0;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastRefreshTime;
  bool _isOnline = true;
  bool _isSearchActive = false;
  String _searchQuery = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  late AnimationController _fabController;
  late AnimationController _staggerController;

  final List<String> _categories = ['All', 'Tech', 'News', 'Science', 'Sports', 'Entertainment'];

  int get _unreadCount => _articles.where((a) => !a.isRead).length;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadViewMode();
    _checkConnectivity();
    _checkForUpdates();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fabController.forward();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _fabController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult.contains(ConnectivityResult.none) == false;
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOnline = results.contains(ConnectivityResult.none) == false;
      });

      // Automatically refresh when coming back online
      if (_isOnline && _articles.isNotEmpty) {
        _refreshFeeds();
      }
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final articlesString = prefs.getString('articles');
    final savedArticlesString = prefs.getString('savedArticles');
    final lastRefresh = prefs.getString('lastRefresh');

    if (articlesString != null) {
      final List<dynamic> decoded = json.decode(articlesString);
      setState(() {
        _articles = decoded.map((json) => Article.fromJson(json as Map<String, dynamic>)).toList();
        _displayedArticles = List.from(_articles);
      });
    }

    if (savedArticlesString != null) {
      final List<dynamic> decoded = json.decode(savedArticlesString);
      setState(() {
        _savedArticles = decoded.map((json) => Article.fromJson(json as Map<String, dynamic>)).toList();
      });
    }

    if (lastRefresh != null) {
      setState(() {
        _lastRefreshTime = DateTime.parse(lastRefresh);
      });
    }

    _staggerController.forward();
    _refreshFeeds();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final viewModeString = prefs.getString('viewMode');
    if (viewModeString != null) {
      setState(() {
        _viewMode = viewModeString == 'list' ? ViewMode.list : ViewMode.cards;
      });
    }
  }

  Future<void> _saveViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('viewMode', _viewMode == ViewMode.list ? 'list' : 'cards');
  }

  Future<void> _checkForUpdates() async {
    // Delay check to avoid showing on first launch
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final updateInfo = await UpdateService.checkForUpdates(forceCheck: true);

    if (mounted && updateInfo != null) {
      showUpdateDialog(context: context, updateInfo: updateInfo);
    }
  }

  Future<void> _saveArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final articlesString = json.encode(_articles.map((a) => a.toJson()).toList());
    await prefs.setString('articles', articlesString);

    final savedArticlesString = json.encode(_savedArticles.map((a) => a.toJson()).toList());
    await prefs.setString('savedArticles', savedArticlesString);

    if (_lastRefreshTime != null) {
      await prefs.setString('lastRefresh', _lastRefreshTime!.toIso8601String());
    }
  }

  Future<void> _refreshFeeds() async {
    // Check if offline
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'You are offline. Showing cached content.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newArticles = await RssFeedService.fetchAllArticles();

      final existingArticleIds = _articles.map((a) => a.id).toSet();
      final articlesToAdd = newArticles.where((a) => !existingArticleIds.contains(a.id)).toList();

      setState(() {
        // Keep existing articles, add new ones, then sort
        _articles.addAll(articlesToAdd);
        _articles.sort((a, b) => b.pubDate.compareTo(a.pubDate));
        _displayedArticles = _getFilteredArticles();
        _lastRefreshTime = DateTime.now();
        _isLoading = false;
      });

      await _saveArticles();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load feeds. Tap to retry.';
        _isLoading = false;
      });
    }
  }

  void _onSwipeRight(int index) {
    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    setState(() {
      _articles[articleIndex].isSaved = true;

      if (!_savedArticles.any((a) => a.id == article.id)) {
        _savedArticles.insert(0, article);
      }

      _articles.removeAt(articleIndex);
      _displayedArticles = _getFilteredArticles();
    });

    _saveArticles();

    _showSnackBar('Article saved', _AppColors.success);
  }

  void _onSwipeLeft(int index) {
    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    setState(() {
      _articles[articleIndex].isRead = true;
      _articles.removeAt(articleIndex);
      _displayedArticles = _getFilteredArticles();
    });

    _saveArticles();

    _showSnackBar('Article marked as read', _AppColors.textSecondary);
  }

  void _onToggleSave(Article article) {
    setState(() {
      article.isSaved = !article.isSaved;

      if (article.isSaved) {
        if (!_savedArticles.any((a) => a.id == article.id)) {
          _savedArticles.insert(0, article);
        }
      } else {
        _savedArticles.removeWhere((a) => a.id == article.id);
      }
    });

    _saveArticles();

    setState(() {
      if (_selectedTab == 1) {
        _savedArticles = _savedArticles.where((a) => a.isSaved).toList();
      }
    });
  }

  void _onTapCard(int index) {
    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    setState(() {
      _articles[articleIndex].isRead = true;
    });
    _saveArticles();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpandedArticleCard(
        article: _articles[articleIndex],
        onClose: () => Navigator.pop(context),
        onToggleSave: () {
          _onToggleSave(_articles[articleIndex]);
        },
      ),
    );
  }

  List<Article> _getFilteredArticles() {
    var articles = _selectedTab == 0 ? _articles.where((a) => !a.isRead).toList() : _savedArticles;

    if (_selectedFilter != 'All' && _selectedTab == 0) {
      articles = articles.where((a) {
        final source = RssFeedService.predefinedSources.firstWhere(
          (s) => s.id == a.sourceId,
          orElse: () => RssFeedService.predefinedSources[0],
        );
        return source.category == _selectedFilter;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      articles = articles.where((a) =>
        a.title.toLowerCase().contains(query) ||
        a.description.toLowerCase().contains(query) ||
        a.sourceName.toLowerCase().contains(query)
      ).toList();
    }

    return articles;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Tech': return _AppColors.techPrimary;
      case 'News': return _AppColors.newsPrimary;
      case 'Science': return _AppColors.sciencePrimary;
      case 'Sports': return _AppColors.sportsPrimary;
      case 'Entertainment': return _AppColors.entertainmentPrimary;
      default: return _AppColors.primary;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        backgroundColor: _AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        elevation: 8,
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  Widget _buildEmptyState() {
    final icon = _selectedTab == 0
        ? (_viewMode == ViewMode.cards ? Icons.style_outlined : Icons.inbox_outlined)
        : Icons.bookmark_outline_rounded;

    final title = _selectedTab == 0
        ? (_viewMode == ViewMode.cards ? 'No articles' : 'No articles yet')
        : 'No saved articles';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: _AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: _AppColors.divider.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 72,
              color: _AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _errorMessage ?? title,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: _AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _refreshFeeds,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ] else if (_selectedTab == 0 && _articles.isEmpty && !_isLoading) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Tap the refresh button to load articles',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: _AppColors.textSecondary,
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_AppColors.accent),
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading feeds...',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _AppColors.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView() {
    return CardStack(
      articles: _displayedArticles,
      onSwipeRight: _onSwipeRight,
      onSwipeLeft: _onSwipeLeft,
      onTap: _onTapCard,
      emptyState: _buildEmptyState(),
      isFilterActive: _selectedFilter != 'All',
    );
  }

  Widget _buildListView() {
    if (_displayedArticles.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _displayedArticles.length,
      itemBuilder: (context, index) {
        final article = _displayedArticles[index];
        final source = RssFeedService.predefinedSources.firstWhere(
          (s) => s.id == article.sourceId,
          orElse: () => RssFeedService.predefinedSources[0],
        );
        final sourceColor = source.color;

        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final delay = index * 0.04;
            final animation = CurvedAnimation(
              parent: _staggerController,
              curve: Interval(
                delay.clamp(0.0, 0.8),
                (delay + 0.15).clamp(0.1, 1.0),
                curve: Curves.easeOutQuart,
              ),
            );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child:child,
              ),
            );
          },
          child: GestureDetector(
            onTap: () => _onTapCard(index),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: _AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: sourceColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _AppColors.divider.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(source.icon, size: 14, color: sourceColor),
                            const SizedBox(width: 6),
                            Text(
                              source.name,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sourceColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: _AppColors.textPrimary,
                                height: 1.3,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              article.description,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: _AppColors.textSecondary,
                                height: 1.5,
                                letterSpacing: 0.05,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.schedule_outlined, size: 12, color: _AppColors.textTertiary),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTimeAgo(article.pubDate),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    color: _AppColors.textTertiary,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.6, 1.0],
          colors: [
            Color(0xFF1A1B4D),
            Color(0xFF2D2F73),
            Color(0xFF4A3B5C),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _selectedTab == 0
                ? 'Curated Feeds'
                : _selectedTab == 1
                    ? 'Saved'
                    : 'Settings',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            if (_selectedTab == 0 && _articles.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_unreadCount',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedTab == 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: _isLoading ? null : _refreshFeeds,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _isSearchActive = !_isSearchActive;
                    if (!_isSearchActive) {
                      _searchQuery = '';
                      _displayedArticles = _getFilteredArticles();
                    }
                  });
                },
                icon: Icon(
                  _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: _AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) async {
                  if (value == 'check_updates') {
                    final updateInfo = await UpdateService.checkForUpdates(forceCheck: true);
                    if (context.mounted) {
                      if (updateInfo != null) {
                        showUpdateDialog(context: context, updateInfo: updateInfo);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You\'re using the latest version!')),
                        );
                      }
                    }
                  } else if (value == 'toggle_view') {
                    setState(() {
                      _viewMode = _viewMode == ViewMode.cards ? ViewMode.list : ViewMode.cards;
                    });
                    _saveViewMode();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'check_updates',
                    child: Row(
                      children: [
                        Icon(Icons.system_update),
                        SizedBox(width: 12),
                        Text('Check for updates'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_view',
                    child: Row(
                      children: [
                        Icon(_viewMode == ViewMode.cards ? Icons.view_list : Icons.grid_view),
                        const SizedBox(width: 12),
                        Text(_viewMode == ViewMode.cards ? 'Switch to List View' : 'Switch to Card View'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Search bar
              if (_isSearchActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search articles, sources, or content...',
                      hintStyle: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: _AppColors.accent,
                          width: 2,
                        ),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _displayedArticles = _getFilteredArticles();
                                });
                              },
                            )
                          : null,
                    ),
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _displayedArticles = _getFilteredArticles();
                      });
                    },
                  ),
                ),

              // Category filter for feeds tab (hide when search is active)
              if (_selectedTab == 0 && !_isSearchActive && (_articles.isNotEmpty || _isLoading == false)) ...[
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = _selectedFilter == category;
                      final color = category == 'All'
                          ? Colors.white
                          : _getCategoryColor(category);

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFilter = category;
                              _displayedArticles = _getFilteredArticles();
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          splashColor: Colors.white.withValues(alpha: 0.1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? color : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : Colors.white.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              category,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Search results indicator
              if (_isSearchActive && _searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Text(
                        '${_displayedArticles.length} result${_displayedArticles.length != 1 ? 's' : ''} for "$_searchQuery"',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              // Offline indicator
              if (!_isOnline && _selectedTab == 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline - Showing cached content',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_isOnline) const SizedBox(height: 8),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : RefreshIndicator(
                        color: _AppColors.accent,
                        backgroundColor: _AppColors.surface,
                        strokeWidth: 2.5,
                        onRefresh: _isLoading ? () async {} : () async {
                          await _refreshFeeds();
                        },
                        child: _selectedTab == 0
                            ? (_viewMode == ViewMode.cards
                                ? _buildCardView()
                                : _buildListView())
                            : _selectedTab == 1
                                ? _buildSavedArticlesView()
                                : _buildSettingsView(),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: _selectedTab == 0 && !_isSearchActive
            ? Container(
                decoration: BoxDecoration(
                  color: _AppColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: FloatingActionButton.small(
                  heroTag: 'view_mode',
                  onPressed: () {
                    setState(() {
                      _viewMode = _viewMode == ViewMode.cards
                          ? ViewMode.list
                          : ViewMode.cards;
                    });
                    _saveViewMode();
                  },
                  backgroundColor: _AppColors.surface,
                  elevation: 0,
                  child: Icon(
                    _viewMode == ViewMode.cards
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: _AppColors.primary,
                    size: 20,
                  ),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
          decoration: BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.rss_feed_rounded,
                      label: 'Feeds',
                      index: 0,
                    ),
                    _buildNavItem(
                      icon: Icons.bookmark_rounded,
                      label: 'Saved',
                      index: 1,
                    ),
                    _buildNavItem(
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      index: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
            if (index == 1) {
              _displayedArticles = List.from(_savedArticles);
            } else if (index == 0) {
              _displayedArticles = _getFilteredArticles();
            }
            // Settings tab (index 2) doesn't need displayed articles
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _AppColors.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? _AppColors.primary : _AppColors.textTertiary,
                        size: 22,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: GoogleFonts.dmSans(
                              color: _AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              letterSpacing: 0.1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedArticlesView() {
    if (_savedArticles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _AppColors.divider.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.bookmark_outline_rounded,
                size: 72,
                color: _AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No saved articles yet',
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Swipe right on articles to save them for later',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: _AppColors.textSecondary,
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _savedArticles.length,
      itemBuilder: (context, index) {
        final article = _savedArticles[index];
        final source = RssFeedService.predefinedSources.firstWhere(
          (s) => s.id == article.sourceId,
          orElse: () => RssFeedService.predefinedSources[0],
        );
        final sourceColor = source.color;

        return Dismissible(
          key: ValueKey(article.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _onToggleSave(article);
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _AppColors.textSecondary,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(Icons.delete_rounded, color: Colors.white, size: 24),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: sourceColor.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(source.icon, size: 14, color: sourceColor),
                        const SizedBox(width: 6),
                        Text(
                          source.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sourceColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _AppColors.textPrimary,
                            height: 1.3,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.description,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            color: _AppColors.textSecondary,
                            height: 1.5,
                            letterSpacing: 0.05,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      article.isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: article.isSaved ? _AppColors.error : _AppColors.textTertiary,
                    ),
                    onPressed: () => _onToggleSave(article),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _buildSettingsSection('About', [
          _buildSettingsItem(
            icon: Icons.info_outline_rounded,
            title: 'Version',
            subtitle: '1.1.3',
            trailing: null,
            onTap: null,
          ),
        ]),
        const SizedBox(height: 20),
        _buildSettingsSection('Appearance', [
          _buildSettingsItem(
            icon: Icons.view_column_outlined,
            title: 'View Mode',
            subtitle: _viewMode == ViewMode.cards ? 'Card View' : 'List View',
            trailing: Icon(
              _viewMode == ViewMode.cards ? Icons.style_outlined : Icons.list_outlined,
              color: _AppColors.textTertiary,
            ),
            onTap: () {
              setState(() {
                _viewMode = _viewMode == ViewMode.cards
                    ? ViewMode.list
                    : ViewMode.cards;
              });
              _saveViewMode();
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildSettingsSection('Data', [
          _buildSettingsItem(
            icon: Icons.bookmark_outline_rounded,
            title: 'Saved Articles',
            subtitle: '${_savedArticles.length} articles saved',
            trailing: null,
            onTap: null,
          ),
        ]),
        const SizedBox(height: 20),
        _buildSettingsSection('Support', [
          _buildSettingsItem(
            icon: Icons.refresh_rounded,
            title: 'Refresh Feeds',
            subtitle: 'Pull down to refresh or tap here',
            trailing: null,
            onTap: _isLoading ? null : _refreshFeeds,
          ),
        ]),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _AppColors.divider.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: _AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: _AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onTap != null) ...[
                if (trailing == null) const Icon(
                  Icons.chevron_right_rounded,
                  color: _AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
