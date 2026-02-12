/// Article Model
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
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      fullContent: json['fullContent'] as String? ?? '',
      link: json['link'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      sourceName: json['sourceName'] as String? ?? 'Unknown Source',
      pubDate: json['pubDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['pubDate'] as int)
          : DateTime.now(),
      author: json['author'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? false,
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
    bool? isRead,
    bool? isSaved,
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
      isRead: isRead ?? this.isRead,
      isSaved: isSaved ?? this.isSaved,
    );
  }
}
