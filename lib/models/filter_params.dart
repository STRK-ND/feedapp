/// Parameters for filtering articles from the Worker API
class FilterParams {
  final int? page;
  final int? pageSize;
  final String? category;
  final List<String>? sources;
  final String? searchQuery;
  final DateTime? since;
  final DateTime? until;
  final SortOption? sortBy;

  const FilterParams({
    this.page,
    this.pageSize,
    this.category,
    this.sources,
    this.searchQuery,
    this.since,
    this.until,
    this.sortBy,
  });

  /// Default pagination params
  const FilterParams.defaults()
    : page = 1,
      pageSize = 50,
      category = null,
      sources = null,
      searchQuery = null,
      since = null,
      until = null,
      sortBy = null;

  /// Create a copy with modified fields
  FilterParams copyWith({
    int? page,
    int? pageSize,
    String? category,
    List<String>? sources,
    String? searchQuery,
    DateTime? since,
    DateTime? until,
    SortOption? sortBy,
  }) {
    return FilterParams(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      category: category ?? this.category,
      sources: sources ?? this.sources,
      searchQuery: searchQuery ?? this.searchQuery,
      since: since ?? this.since,
      until: until ?? this.until,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  /// Convert to query string parameters
  Map<String, String> toQueryParams() {
    final params = <String, String>{};

    if (page != null && page != 1) {
      params['page'] = page.toString();
    }
    if (pageSize != null && pageSize != 50) {
      params['pageSize'] = pageSize.toString();
    }
    if (category != null && category != 'All') {
      params['category'] = category!;
    }
    if (sources != null && sources!.isNotEmpty) {
      params['source'] = sources!.join(',');
    }
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      params['q'] = searchQuery!;
    }
    if (since != null) {
      params['since'] = since!.toIso8601String();
    }
    if (until != null) {
      params['until'] = until!.toIso8601String();
    }
    if (sortBy != null) {
      params['sort'] = sortBy!.value;
    }

    return params;
  }
}

/// Sort options for articles
enum SortOption {
  dateDesc('date_desc'),
  dateAsc('date_asc'),
  source('source');

  final String value;
  const SortOption(this.value);
}
