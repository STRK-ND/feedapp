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

  /// Muted keywords — the worker drops matching articles server-side so
  /// delta fetches don't ship rows the client would hide anyway. Expected
  /// already normalized (see `utils/mute_filter.dart`); the worker clamps
  /// defensively regardless.
  final List<String>? mutedTerms;

  const FilterParams({
    this.page,
    this.pageSize,
    this.category,
    this.sources,
    this.searchQuery,
    this.since,
    this.until,
    this.sortBy,
    this.mutedTerms,
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
      sortBy = null,
      mutedTerms = null;

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
    List<String>? mutedTerms,
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
      mutedTerms: mutedTerms ?? this.mutedTerms,
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
      // Worker expects epoch millis (article.pubDate is stored as ms).
      params['since'] = since!.millisecondsSinceEpoch.toString();
    }
    if (until != null) {
      // Same epoch-ms contract as `since` — worker parses both identically.
      params['until'] = until!.millisecondsSinceEpoch.toString();
    }
    if (sortBy != null) {
      params['sort'] = sortBy!.value;
    }
    if (mutedTerms != null && mutedTerms!.isNotEmpty) {
      params['mute'] = mutedTerms!.join(',');
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
