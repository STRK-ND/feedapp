/// Article Model
///
/// ID format: compound key "sourceId:originalId" to prevent collisions
/// between Worker API (numeric IDs) and RSS feeds (link.hashCode IDs)
import '../utils/helpers.dart';

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
  // Source metadata from Worker API
  final String? sourceCategory;
  final String? sourceColor;
  final String? sourceIcon;
  bool isRead;
  bool isSaved;
  String? fetchedFullContent;

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
    this.sourceCategory,
    this.sourceColor,
    this.sourceIcon,
    this.isRead = false,
    this.isSaved = false,
    this.fetchedFullContent,
  });

  /// Creates a compound article ID from source and original ID
  /// Format: "sourceId:originalId"
  /// Examples: "worker:123", "verge:9876543"
  static String makeId(String sourceId, String originalId) {
    return '$sourceId:$originalId';
  }

  /// Extracts the sourceId from a compound article ID
  /// Returns null if the ID doesn't match compound format
  static String? extractSourceId(String articleId) {
    final parts = articleId.split(':');
    return parts.length == 2 ? parts[0] : null;
  }

  /// Extracts the original ID from a compound article ID
  /// Returns the full ID if it doesn't match compound format (backwards compat)
  static String extractOriginalId(String articleId) {
    final parts = articleId.split(':');
    return parts.length == 2 ? parts[1] : articleId;
  }

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
      'sourceCategory': sourceCategory,
      'sourceColor': sourceColor,
      'sourceIcon': sourceIcon,
      'isRead': isRead,
      'isSaved': isSaved,
      'fetchedFullContent': fetchedFullContent,
    };
  }

  /// Parse pubDate from various formats (int timestamp or DateTime)
  static DateTime _parsePubDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Creates an Article from JSON with compound key handling
  /// Worker API returns int IDs → converted to "sourceId:intId" format
  /// RSS feeds use link.hashCode → converted to "sourceId:hashCode" format
  factory Article.fromJson(Map<String, dynamic> json) {
    // Handle id as either int or string (Worker API returns int, local storage uses string)
    final dynamic rawId = json['id'];
    final String sourceId = json['sourceId'] as String? ?? '';
    final String id;

    if (rawId is int) {
      // Worker API: int ID → compound key
      id = Article.makeId(sourceId, rawId.toString());
    } else if (rawId is String && rawId.contains(':')) {
      // Already a compound key (from local storage)
      id = rawId;
    } else {
      // RSS or unknown: string ID → compound key
      id = Article.makeId(sourceId, rawId as String? ?? '');
    }

    // Validate image URL
    String? imageUrl = json['imageUrl'] as String?;
    if (imageUrl != null && !Helpers.isValidImageUrl(imageUrl)) {
      imageUrl = null;
    }

    return Article(
      id: id,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      fullContent: json['fullContent'] as String? ?? '',
      link: json['link'] as String? ?? '',
      sourceId: sourceId,
      sourceName: json['sourceName'] as String? ?? 'Unknown Source',
      pubDate: _parsePubDate(json['pubDate']),
      author: json['author'] as String?,
      imageUrl: json['imageUrl'] as String?,
      sourceCategory: json['sourceCategory'] as String?,
      sourceColor: json['sourceColor'] as String?,
      sourceIcon: json['sourceIcon'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
      fetchedFullContent: json['fetchedFullContent'] as String?,
    );
  }

  Article copyWith({
    String? id,
    String? title,
    String? description,
    String? fullContent,
    String? link,
    String? sourceId,
    String? sourceName,
    DateTime? pubDate,
    String? author,
    String? imageUrl,
    String? sourceCategory,
    String? sourceColor,
    String? sourceIcon,
    bool? isRead,
    bool? isSaved,
    String? fetchedFullContent,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      fullContent: fullContent ?? this.fullContent,
      link: link ?? this.link,
      sourceId: sourceId ?? this.sourceId,
      sourceName: sourceName ?? this.sourceName,
      pubDate: pubDate ?? this.pubDate,
      author: author ?? this.author,
      imageUrl: imageUrl ?? this.imageUrl,
      sourceCategory: sourceCategory ?? this.sourceCategory,
      sourceColor: sourceColor ?? this.sourceColor,
      sourceIcon: sourceIcon ?? this.sourceIcon,
      isRead: isRead ?? this.isRead,
      isSaved: isSaved ?? this.isSaved,
      fetchedFullContent: fetchedFullContent ?? this.fetchedFullContent,
    );
  }
}
