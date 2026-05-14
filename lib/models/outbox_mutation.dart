/// Represents a mutation action to be replayed when connectivity is restored
class OutboxMutation {
  final String id;
  final OutboxMutationType type;
  final String articleId;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;
  int retryCount;

  OutboxMutation({
    required this.id,
    required this.type,
    required this.articleId,
    this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'articleId': articleId,
    'payload': payload,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'retryCount': retryCount,
  };

  factory OutboxMutation.fromJson(Map<String, dynamic> json) {
    return OutboxMutation(
      id: json['id'] as String,
      type: OutboxMutationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => OutboxMutationType.markRead,
      ),
      articleId: json['articleId'] as String,
      payload: json['payload'] as Map<String, dynamic>?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  OutboxMutation copyWith({int? retryCount}) {
    return OutboxMutation(
      id: id,
      type: type,
      articleId: articleId,
      payload: payload,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

enum OutboxMutationType {
  markRead,
  markUnread,
  saveArticle,
  unsaveArticle,
  toggleRead,
  toggleSave,
}