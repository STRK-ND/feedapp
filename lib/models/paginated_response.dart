import 'article.dart';

/// Paginated Response Model for Worker API
class PaginatedResponse {
  final List<Article> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  /// Returns the next page number, or null if there are no more pages
  int? get nextPage => hasMore ? page + 1 : null;

  /// Calculates total pages based on total items and page size
  int get totalPages => (total / pageSize).ceil();

  factory PaginatedResponse.fromJson(Map<String, dynamic> json) {
    return PaginatedResponse(
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => Article.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? 50,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}
