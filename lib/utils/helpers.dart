import '../models/article.dart';

/// Utility functions for common operations
class Helpers {
  Helpers._();

  /// Format a date/datetime as "time ago" (e.g., "2h ago", "5d ago")
  static String formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Format a date as "dd/mm/yyyy HH:MM"
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Strip HTML tags from a string
  static String stripHtmlTags(String htmlString) {
    final regex = RegExp(r'<[^>]*>', multiLine: true);
    return htmlString.replaceAll(regex, '').trim();
  }

  /// Truncate text with ellipsis if it exceeds maxLength
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Check if a URL contains a valid image extension or pattern
  static bool isValidImageUrl(String url) {
    if (url.isEmpty) return false;

    final lowerUrl = url.toLowerCase();

    // Block URLs that require authentication or have expired signatures
    const blockedPatterns = [
      'o.aolcdn.com', // AOL images require authentication
      'media.m半岛日报.com',
      'dims?image_uri',
    ];
    for (final pattern in blockedPatterns) {
      if (lowerUrl.contains(pattern.toLowerCase())) return false;
    }

    // Check for common image file extensions
    const validExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.svg',
      '.avif',
      '.heic',
      '.ico',
      '.tif',
      '.tiff',
    ];
    for (final ext in validExtensions) {
      if (lowerUrl.contains(ext)) return true;
    }

    // Check for common image CDN patterns
    const imagePatterns = [
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
    ];

    for (final pattern in imagePatterns) {
      if (lowerUrl.contains(pattern)) return true;
    }

    // Accept URLs that look like they might be images based on parameters
    if (lowerUrl.contains('image') ||
        lowerUrl.contains('photo') ||
        lowerUrl.contains('picture')) {
      return true;
    }

    // Accept URLs that have dimensions (often image thumbnails)
    if (lowerUrl.contains('&width=') ||
        lowerUrl.contains('&height=') ||
        lowerUrl.contains('?width=') ||
        lowerUrl.contains('?height=') ||
        lowerUrl.contains('w=') ||
        lowerUrl.contains('h=')) {
      return true;
    }

    // Accept URLs that look like content delivery
    if (lowerUrl.contains('content') &&
        (lowerUrl.contains('cdn') || lowerUrl.contains('media'))) {
      return true;
    }

    return false;
  }

  /// Parse date, trying ISO format first, falls back to null
  static DateTime parseDate(String dateString) {
    return DateTime.tryParse(dateString) ?? DateTime.now();
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  /// Compare two semver version strings. Returns true if [latest] > [current].
  static bool isNewerVersion(String current, String latest) {
    // Strip build number and 'v' prefix
    if (current.contains('+')) current = current.split('+')[0];
    if (latest.contains('+')) latest = latest.split('+')[0];
    if (latest.startsWith('v')) latest = latest.substring(1);

    final currentParts = current.split('.')..removeWhere((e) => e.isEmpty);
    final latestParts = latest.split('.')..removeWhere((e) => e.isEmpty);

    for (int i = 0; i < 3; i++) {
      final currentNum = i < currentParts.length
          ? int.tryParse(currentParts[i]) ?? 0
          : 0;
      final latestNum = i < latestParts.length
          ? int.tryParse(latestParts[i]) ?? 0
          : 0;

      if (latestNum > currentNum) return true;
      if (latestNum < currentNum) return false;
    }

    return false;
  }

  /// Filter articles by search query across title, description, and source name
  static List<Article> filterArticlesByQuery(
    List<Article> articles,
    String query,
  ) {
    if (query.isEmpty) return articles;

    final lowerQuery = query.toLowerCase();
    return articles.where((a) {
      return a.title.toLowerCase().contains(lowerQuery) ||
          a.description.toLowerCase().contains(lowerQuery) ||
          a.sourceName.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Filter articles by category
  static List<Article> filterArticlesByCategory(
    List<Article> articles,
    String category,
  ) {
    if (category == 'All' || category.isEmpty) {
      return articles;
    }
    return articles.where((a) => a.sourceCategory == category).toList();
  }
}
