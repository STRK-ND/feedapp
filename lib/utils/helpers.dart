import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Utility functions for common operations
class Helpers {
  Helpers._();

  /// Check if the user prefers reduced motion based on system settings.
  ///
  /// This respects both accessibility settings for accessible navigation
  /// and explicit reduced motion preferences.
  ///
  /// Use this to conditionally disable or reduce animations:
  /// ```dart
  /// if (Helpers.prefersReducedMotion) {
  ///   // Use shorter duration or no animation
  /// } else {
  ///   // Normal animation
  /// }
  /// ```
  static bool get prefersReducedMotion {
    final platformDispatcher = PlatformDispatcher.instance;
    return platformDispatcher.accessibilityFeatures.accessibleNavigation ||
        platformDispatcher.accessibilityFeatures.reduceMotion;
  }

  /// Get an appropriate animation duration based on reduced motion preference.
  ///
  /// [normalDuration] - The full animation duration
  /// [reducedDuration] - The shortened duration for reduced motion (default: 100ms)
  static Duration getAnimationDuration(
    Duration normalDuration, {
    Duration reducedDuration = const Duration(milliseconds: 100),
  }) {
    return prefersReducedMotion ? reducedDuration : normalDuration;
  }

  /// Get an appropriate animation curve based on reduced motion preference.
  ///
  /// [normalCurve] - The standard animation curve
  /// [reducedCurve] - The curve for reduced motion (default: Curves.linear)
  static Curve getAnimationCurve({
    Curve normalCurve = Curves.easeOut,
    Curve reducedCurve = Curves.linear,
  }) {
    return prefersReducedMotion ? reducedCurve : normalCurve;
  }

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

    // Check for common image file extensions
    const validExtensions = [
      '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.avif',
      '.heic', '.ico', '.tif', '.tiff'
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
    if (lowerUrl.contains('image')
        || lowerUrl.contains('photo')
        || lowerUrl.contains('picture')) {
      return true;
    }

    // Accept URLs that have dimensions (often image thumbnails)
    if (lowerUrl.contains('&width=')
        || lowerUrl.contains('&height=')
        || lowerUrl.contains('?width=')
        || lowerUrl.contains('?height=')
        || lowerUrl.contains('w=')
        || lowerUrl.contains('h=')) {
      return true;
    }

    // Accept URLs that look like content delivery
    if (lowerUrl.contains('content')
        && (lowerUrl.contains('cdn') || lowerUrl.contains('media'))) {
      return true;
    }

    return false;
  }

  /// Parse a custom date format (e.g., "15 Jan 2024")
  static DateTime parseCustomDate(String dateStr) {
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

  /// Parse date, trying ISO format first, falls back to custom format
  static DateTime parseDate(String dateString) {
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      try {
        return parseCustomDate(dateString);
      } catch (e2) {
        return DateTime.now();
      }
    }
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  /// Generate a hash from a string (for article IDs)
  static int generateHash(String input) {
    return _hashCode(input);
  }

  static int _hashCode(String string) {
    var hash = 0xcbf29ce484222325.toUnsigned(64);

    for (var i = 0; i < string.length; i++) {
      final codeUnit = string.codeUnitAt(i);
      hash = (hash ^ (codeUnit >> 8)).toUnsigned(64);
      hash = (hash * 0x100000001b3).toUnsigned(64);
      hash = (hash ^ (codeUnit & 0xFF)).toUnsigned(64);
      hash = (hash * 0x100000001b3).toUnsigned(64);
    }

    return hash;
  }
}
