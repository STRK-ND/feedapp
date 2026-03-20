# Worker Advanced Filtering Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add advanced filtering endpoints (pagination, category, source, search, date range), source metadata endpoint, and full-content extraction to the Cloudflare Worker; update Flutter WorkerFeedService to support these features.

**Architecture:** Extend the existing Worker with query parameter parsing and server-side filtering logic; add a full-content extraction endpoint using fetch + HTML parsing; update Flutter to build query strings from FilterParams objects and handle paginated responses.

**Tech Stack:** Cloudflare Workers (JavaScript), Flutter/Dart (http package), HTML parsing for content extraction

---

## Task 1: Add Query Parameter Parsing & Pagination to Worker

**Files:**
- Modify: `workers/feed-worker.js:86-97`
- Test: Manual/curl test

**Context:** The current `handleFetch()` fetches all sources and returns all articles. We need to add query parameter support for pagination.

- [ ] **Step 1: Add utility functions for pagination**
  ```javascript
  // Add after line 77 (after hashCode function)
  function parseIntOrDefault(value, defaultValue) {
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? defaultValue : parsed;
  }

  function paginateItems(items, page, pageSize) {
    const start = (page - 1) * pageSize;
    const end = start + pageSize;
    return {
      items: items.slice(start, end),
      total: items.length,
      page: page,
      pageSize: pageSize,
      hasMore: end < items.length
    };
  }
  ```

- [ ] **Step 2: Update handleFetch to extract query params**
  ```javascript
  // Replace line 86-97 handleFetch function signature and body
  async function handleFetch(req) {
    const url = new URL(req.url);
    const cache = caches.default;
    const key = req.url;  // Use full URL with query params as cache key

    // Parse query parameters
    const page = parseIntOrDefault(url.searchParams.get('page'), 1);
    const pageSize = parseIntOrDefault(url.searchParams.get('pageSize'), 50);
    const maxPageSize = 100;
    const effectivePageSize = Math.min(pageSize, maxPageSize);

    // Try cache first
    try {
      const cached = await cache.match(key);
      if (cached) return cached;
    } catch(e) {}

    // Fetch and aggregate articles (same as before)
    const results = await Promise.allSettled(RSS_SOURCES.map(s => fetchSource(s)));
    const allArticles = [];
    for (const result of results) {
      if (result.status === 'fulfilled') {
        allArticles.push(...result.value);
      }
    }

    // Sort by date
    allArticles.sort((a, b) => new Date(b.pubDate) - new Date(a.pubDate));

    // Paginate
    const paginated = paginateItems(allArticles, page, effectivePageSize);

    const response = new Response(JSON.stringify(paginated), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=' + CACHE_TTL
      }
    });

    try {
      await cache.put(key, response.clone());
    } catch(e) {}

    return response;
  }
  ```

- [ ] **Step 3: Test pagination locally with wrangler**
  Run: `cd workers && npx wrangler dev`
  Test: `curl "http://localhost:8787/?page=1&pageSize=10"`
  Expected: JSON response with `items`, `total`, `page`, `pageSize`, `hasMore`

- [ ] **Step 4: Commit**
  ```bash
  git add workers/feed-worker.js
  git commit -m "feat(worker): add pagination support with page and pageSize params"
  ```

---

## Task 2: Add Filtering by Category, Source, and Search to Worker

**Files:**
- Modify: `workers/feed-worker.js:86-97`
- Test: Manual/curl test

**Context:** Extend handleFetch to support filtering before pagination.

- [ ] **Step 1: Add filter functions before handleFetch**
  ```javascript
  // Add after paginateItems function
  function filterArticlesByCategory(articles, category) {
    if (!category || category === 'All') return articles;
    return articles.filter(a =>
      a.sourceCategory?.toLowerCase() === category.toLowerCase()
    );
  }

  function filterArticlesBySource(articles, sourceId) {
    if (!sourceId) return articles;
    const ids = sourceId.split(',').map(s => s.trim().toLowerCase());
    return articles.filter(a =>
      ids.includes(a.sourceId?.toLowerCase())
    );
  }

  function filterArticlesBySearch(articles, query) {
    if (!query) return articles;
    const lowerQuery = query.toLowerCase();
    return articles.filter(a =>
      a.title?.toLowerCase().includes(lowerQuery) ||
      a.description?.toLowerCase().includes(lowerQuery) ||
      a.sourceName?.toLowerCase().includes(lowerQuery)
    );
  }

  function filterArticlesByDateRange(articles, since, until) {
    return articles.filter(a => {
      const pubDate = new Date(a.pubDate);
      if (since && pubDate < new Date(since)) return false;
      if (until && pubDate > new Date(until)) return false;
      return true;
    });
  }

  function sortArticles(articles, sortBy) {
    const sorted = [...articles];
    switch (sortBy) {
      case 'date_asc':
        sorted.sort((a, b) => new Date(a.pubDate) - new Date(b.pubDate));
        break;
      case 'source':
        sorted.sort((a, b) => a.sourceName.localeCompare(b.sourceName));
        break;
      case 'date_desc':
      default:
        sorted.sort((a, b) => new Date(b.pubDate) - new Date(a.pubDate));
        break;
    }
    return sorted;
  }
  ```

- [ ] **Step 2: Update handleFetch to apply filters**
  ```javascript
  async function handleFetch(req) {
    const url = new URL(req.url);
    const cache = caches.default;
    const key = req.url;

    // Parse query parameters
    const page = parseIntOrDefault(url.searchParams.get('page'), 1);
    const pageSize = parseIntOrDefault(url.searchParams.get('pageSize'), 50);
    const maxPageSize = 100;
    const effectivePageSize = Math.min(pageSize, maxPageSize);

    // Filtering params
    const category = url.searchParams.get('category');
    const source = url.searchParams.get('source');
    const search = url.searchParams.get('q');
    const since = url.searchParams.get('since');
    const until = url.searchParams.get('until');
    const sort = url.searchParams.get('sort') || 'date_desc';

    // Try cache first
    try {
      const cached = await cache.match(key);
      if (cached) return cached;
    } catch(e) {}

    // Fetch articles
    const results = await Promise.allSettled(RSS_SOURCES.map(s => fetchSource(s)));
    let allArticles = [];
    for (const result of results) {
      if (result.status === 'fulfilled') {
        allArticles.push(...result.value);
      }
    }

    // Apply filters
    allArticles = filterArticlesByCategory(allArticles, category);
    allArticles = filterArticlesBySource(allArticles, source);
    allArticles = filterArticlesBySearch(allArticles, search);
    allArticles = filterArticlesByDateRange(allArticles, since, until);
    allArticles = sortArticles(allArticles, sort);

    // Paginate
    const paginated = paginateItems(allArticles, page, effectivePageSize);

    const response = new Response(JSON.stringify(paginated), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=' + CACHE_TTL
      }
    });

    try {
      await cache.put(key, response.clone());
    } catch(e) {}

    return response;
  }
  ```

- [ ] **Step 3: Test filtering with curl**
  Run: `cd workers && npx wrangler dev`
  Test categories:
  ```bash
  curl "http://localhost:8787/?category=Tech&pageSize=5"
  curl "http://localhost:8787/?source=techcrunch&pageSize=5"
  curl "http://localhost:8787/?q=AI&pageSize=5"
  curl "http://localhost:8787/?sort=source&pageSize=10"
  ```
  Expected: Each returns filtered results matching the criteria

- [ ] **Step 4: Commit**
  ```bash
  git add workers/feed-worker.js
  git commit -m "feat(worker): add category, source, search, date range filtering and sorting"
  ```

---

## Task 3: Add /sources Endpoint to Worker

**Files:**
- Modify: `workers/feed-worker.js:99-106`
- Test: Manual/curl test

**Context:** Add an endpoint to return available sources with their metadata.

- [ ] **Step 1: Add sources endpoint handler before export default**
  ```javascript
  // Add before export default
  function handleSources() {
    const sources = RSS_SOURCES.map(s => ({
      id: s.id,
      name: s.name,
      category: s.category,
      color: s.color,
      icon: s.icon,
      url: s.url
    }));

    return new Response(JSON.stringify({ sources }), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=3600'  // Cache for 1 hour
      }
    });
  }
  ```

- [ ] **Step 2: Update main fetch handler**
  ```javascript
  export default {
    async fetch(req) {
      const url = new URL(req.url);

      if (req.method === 'OPTIONS') {
        return new Response(null, {
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
          }
        });
      }

      if (url.pathname === '/sources') {
        return handleSources();
      }

      if (url.pathname === '/health') {
        return new Response(JSON.stringify({ status: 'ok' }), {
          headers: { 'Content-Type': 'application/json' }
        });
      }

      if (url.pathname === '/test') {
        return new Response(JSON.stringify([{
          id: '1',
          title: 'Test',
          description: 'Test',
          sourceId: 'techcrunch',
          sourceName: 'TechCrunch',
          pubDate: new Date().toISOString()
        }]), {
          headers: { 'Content-Type': 'application/json' }
        });
      }

      if (req.method === 'GET') {
        return handleFetch(req);
      }

      return new Response('Method not allowed', { status: 405 });
    }
  };
  ```

- [ ] **Step 3: Test /sources endpoint**
  Run: `cd workers && npx wrangler dev`
  Test: `curl "http://localhost:8787/sources"`
  Expected: JSON with array of sources including id, name, category, color, icon, url

- [ ] **Step 4: Commit**
  ```bash
  git add workers/feed-worker.js
  git commit -m "feat(worker): add /sources endpoint returning available RSS sources"
  ```

---

## Task 4: Add Full-Content Extraction Endpoint to Worker

**Files:**
- Modify: `workers/feed-worker.js`
- Create: Add readability extraction functions
- Test: Manual/curl test

**Context:** Add an endpoint that fetches a full article and extracts readable content using a simple HTML-to-text approach.

- [ ] **Step 1: Add HTML content extraction functions**
  ```javascript
  // Add after existing utility functions (around line 44)
  function extractArticleContent(html, articleUrl) {
    // Remove script and style elements
    let content = html.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
    content = content.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');

    // Try to find article content in common containers
    const contentPatterns = [
      /<article[^>]*>([\s\S]*?)<\/article>/i,
      /<main[^>]*>([\s\S]*?)<\/main>/i,
      /<div[^>]*class=["'][^"']*(?:article|post|content|entry)[^"']*["'][^>]*>([\s\S]*?)<\/div>/i,
      /<div[^>]*id=["'][^"']*(?:article|post|content|entry)["'][^>]*>([\s\S]*?)<\/div>/i
    ];

    let extractedContent = '';
    for (const pattern of contentPatterns) {
      const match = content.match(pattern);
      if (match) {
        extractedContent = match[1];
        break;
      }
    }

    // If no specific container found, use body
    if (!extractedContent) {
      const bodyMatch = content.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
      extractedContent = bodyMatch ? bodyMatch[1] : content;
    }

    // Clean up HTML
    extractedContent = stripHtmlTags(extractedContent);
    extractedContent = cleanHtmlEntities(extractedContent);

    // Remove common non-content elements
    const nonContentPatterns = [
      /Follow us.*?\./gi,
      /Subscribe to.*?\./gi,
      /Sign up for.*?\./gi,
      /Read more.*?\./gi,
      /Related articles.*?$/gi,
      /You might also like.*?$/gi,
      /Comments.*?$/gi,
      /Share this.*?$/gi,
    ];

    for (const pattern of nonContentPatterns) {
      extractedContent = extractedContent.replace(pattern, '');
    }

    // Clean up whitespace
    extractedContent = extractedContent.replace(/\s{2,}/g, ' ').trim();

    return extractedContent;
  }

  async function fetchFullContent(articleUrl) {
    try {
      const response = await fetch(articleUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; CuratedFeedsBot/1.0)'
        }
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const html = await response.text();
      return extractArticleContent(html, articleUrl);
    } catch (error) {
      console.error(`Failed to fetch content from ${articleUrl}:`, error.message);
      return null;
    }
  }
  ```

- [ ] **Step 2: Add full-content endpoint handler**
  ```javascript
  // Add before export default
  async function handleFullContent(req) {
    const url = new URL(req.url);
    const articleUrl = url.searchParams.get('url');

    if (!articleUrl) {
      return new Response(
        JSON.stringify({ error: 'Missing url parameter' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        }
      );
    }

    // Validate URL
    try {
      new URL(articleUrl);
    } catch {
      return new Response(
        JSON.stringify({ error: 'Invalid URL' }),
        {
          status: 400,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        }
      );
    }

    const content = await fetchFullContent(articleUrl);

    if (!content) {
      return new Response(
        JSON.stringify({ error: 'Failed to fetch or extract content' }),
        {
          status: 500,
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
          }
        }
      );
    }

    return new Response(
      JSON.stringify({
        url: articleUrl,
        content: content,
        wordCount: content.split(/\s+/).length,
        fetchedAt: new Date().toISOString()
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'public, max-age=3600'
        }
      }
    );
  }
  ```

- [ ] **Step 3: Update main router**
  ```javascript
  export default {
    async fetch(req) {
      const url = new URL(req.url);

      if (req.method === 'OPTIONS') {
        return new Response(null, {
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
          }
        });
      }

      if (url.pathname === '/sources') {
        return handleSources();
      }

      if (url.pathname === '/full-content') {
        return handleFullContent(req);
      }

      if (url.pathname === '/health') {
        return new Response(JSON.stringify({ status: 'ok' }), {
          headers: { 'Content-Type': 'application/json' }
        });
      }

      if (url.pathname === '/test') {
        return new Response(JSON.stringify([{
          id: '1',
          title: 'Test',
          description: 'Test',
          sourceId: 'techcrunch',
          sourceName: 'TechCrunch',
          pubDate: new Date().toISOString()
        }]), {
          headers: { 'Content-Type': 'application/json' }
        });
      }

      if (req.method === 'GET') {
        return handleFetch(req);
      }

      return new Response('Method not allowed', { status: 405 });
    }
  };
  ```

- [ ] **Step 4: Test full-content extraction**
  Run: `cd workers && npx wrangler dev`
  Test: `curl "http://localhost:8787/full-content?url=https://example.com/article"`
  Expected: JSON with extracted content, wordCount, and fetchedAt

- [ ] **Step 5: Commit**
  ```bash
  git add workers/feed-worker.js
  git commit -m "feat(worker): add /full-content endpoint for article extraction"
  ```

---

## Task 5: Create PaginatedResponse Model in Flutter

**Files:**
- Create: `lib/models/paginated_response.dart`
- Test: `test/unit/models/paginated_response_test.dart`

**Context:** Create a model to represent paginated responses from the Worker.

- [ ] **Step 1: Create the PaginatedResponse model**
  ```dart
  import 'article.dart';

  /// Represents a paginated response from the Worker API
  class PaginatedResponse {
    final List<Article> items;
    final int total;
    final int page;
    final int pageSize;
    final bool hasMore;

    const PaginatedResponse({
      required this.items,
      required this.total,
      required this.page,
      required this.pageSize,
      required this.hasMore,
    });

    factory PaginatedResponse.fromJson(Map<String, dynamic> json) {
      return PaginatedResponse(
        items: (json['items'] as List<dynamic>)
            .map((item) => Article.fromJson(item as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pageSize: json['pageSize'] as int,
        hasMore: json['hasMore'] as bool,
      );
    }

    Map<String, dynamic> toJson() {
      return {
        'items': items.map((a) => a.toJson()).toList(),
        'total': total,
        'page': page,
        'pageSize': pageSize,
        'hasMore': hasMore,
      };
    }

    /// Calculate the next page number, or null if no more pages
    int? get nextPage => hasMore ? page + 1 : null;

    /// Calculate total number of pages
    int get totalPages => (total / pageSize).ceil();
  }
  ```

- [ ] **Step 2: Write tests for PaginatedResponse**
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:curated_feeds/models/paginated_response.dart';
  import 'package:curated_feeds/models/article.dart';

  void main() {
    group('PaginatedResponse', () {
      test('should parse from JSON', () {
        final json = {
          'items': [
            {
              'id': '1',
              'title': 'Test Article',
              'description': 'Test Description',
              'fullContent': 'Full Content',
              'link': 'https://example.com',
              'sourceId': 'techcrunch',
              'sourceName': 'TechCrunch',
              'sourceCategory': 'Tech',
              'sourceColor': '#3B82F6',
              'sourceIcon': 'rocket',
              'pubDate': DateTime.now().millisecondsSinceEpoch,
            }
          ],
          'total': 100,
          'page': 1,
          'pageSize': 20,
          'hasMore': true,
        };

        final response = PaginatedResponse.fromJson(json);

        expect(response.items.length, 1);
        expect(response.items[0].title, 'Test Article');
        expect(response.total, 100);
        expect(response.page, 1);
        expect(response.pageSize, 20);
        expect(response.hasMore, true);
      });

      test('should calculate nextPage correctly', () {
        final response = PaginatedResponse(
          items: [],
          total: 100,
          page: 1,
          pageSize: 20,
          hasMore: true,
        );

        expect(response.nextPage, 2);
      });

      test('should return null nextPage when no more items', () {
        final response = PaginatedResponse(
          items: [],
          total: 20,
          page: 1,
          pageSize: 20,
          hasMore: false,
        );

        expect(response.nextPage, null);
      });

      test('should calculate totalPages correctly', () {
        final response = PaginatedResponse(
          items: [],
          total: 100,
          page: 1,
          pageSize: 20,
          hasMore: true,
        );

        expect(response.totalPages, 5);
      });

      test('should serialize to JSON', () {
        final response = PaginatedResponse(
          items: [],
          total: 100,
          page: 1,
          pageSize: 20,
          hasMore: true,
        );

        final json = response.toJson();

        expect(json['total'], 100);
        expect(json['page'], 1);
        expect(json['pageSize'], 20);
        expect(json['hasMore'], true);
      });
    });
  }
  ```

- [ ] **Step 3: Run tests to verify**
  Run: `flutter test test/unit/models/paginated_response_test.dart`
  Expected: 4 tests passing

- [ ] **Step 4: Commit**
  ```bash
  git add lib/models/paginated_response.dart test/unit/models/paginated_response_test.dart
  git commit -m "feat(models): add PaginatedResponse model with pagination helpers"
  ```

---

## Task 6: Create FilterParams Model for Query Building

**Files:**
- Create: `lib/models/filter_params.dart`
- Test: `test/unit/models/filter_params_test.dart`

**Context:** Create a model to hold filter parameters and build query strings.

- [ ] **Step 1: Create the FilterParams model**
  ```dart
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
      bool clearCategory = false,
      bool clearSources = false,
      bool clearSearch = false,
      bool clearSince = false,
      bool clearUntil = false,
      bool clearSortBy = false,
    }) {
      return FilterParams(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        category: clearCategory ? null : (category ?? this.category),
        sources: clearSources ? null : (sources ?? this.sources),
        searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
        since: clearSince ? null : (since ?? this.since),
        until: clearUntil ? null : (until ?? this.until),
        sortBy: clearSortBy ? null : (sortBy ?? this.sortBy),
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

    /// Build a URL with query parameters
    String buildUrl(String baseUrl) {
      final params = toQueryParams();
      if (params.isEmpty) return baseUrl;

      final uri = Uri.parse(baseUrl).replace(queryParameters: params);
      return uri.toString();
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
  ```

- [ ] **Step 2: Write tests for FilterParams**
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:curated_feeds/models/filter_params.dart';

  void main() {
    group('FilterParams', () {
      test('should build query params with all fields', () {
        final params = FilterParams(
          page: 2,
          pageSize: 20,
          category: 'Tech',
          sources: ['techcrunch', 'verge'],
          searchQuery: 'AI',
          since: DateTime.parse('2024-01-01'),
          until: DateTime.parse('2024-12-31'),
          sortBy: SortOption.source,
        );

        final query = params.toQueryParams();

        expect(query['page'], '2');
        expect(query['pageSize'], '20');
        expect(query['category'], 'Tech');
        expect(query['source'], 'techcrunch,verge');
        expect(query['q'], 'AI');
        expect(query['sort'], 'source');
      });

      test('should omit default values', () {
        final params = FilterParams(
          page: 1,
          pageSize: 50,
          category: 'All',
        );

        final query = params.toQueryParams();

        expect(query.containsKey('page'), false);
        expect(query.containsKey('pageSize'), false);
        expect(query.containsKey('category'), false);
      });

      test('should build URL with query params', () {
        final params = FilterParams(
          category: 'Tech',
          pageSize: 10,
        );

        final url = params.buildUrl('https://api.example.com/articles');

        expect(url, contains('category=Tech'));
        expect(url, contains('pageSize=10'));
      });

      test('should copy with modifications', () {
        final params = FilterParams(category: 'Tech', page: 1);
        final updated = params.copyWith(page: 2, category: 'News');

        expect(updated.page, 2);
        expect(updated.category, 'News');
      });

      test('should clear fields when requested', () {
        final params = FilterParams(category: 'Tech', page: 2);
        final cleared = params.copyWith(clearCategory: true);

        expect(cleared.category, null);
        expect(cleared.page, 2);
      });
    });
  }
  ```

- [ ] **Step 3: Run tests to verify**
  Run: `flutter test test/unit/models/filter_params_test.dart`
  Expected: 5 tests passing

- [ ] **Step 4: Commit**
  ```bash
  git add lib/models/filter_params.dart test/unit/models/filter_params_test.dart
  git commit -m "feat(models): add FilterParams with query string building"
  ```

---

## Task 7: Update WorkerFeedService for Pagination and Filtering

**Files:**
- Modify: `lib/services/worker_feed_service.dart`
- Test: `test/unit/services/worker_feed_service_test.dart`

**Context:** Update the existing service to support pagination and filtering.

- [ ] **Step 1: Update imports and add new methods**
  ```dart
  import 'package:flutter/foundation.dart';
  import 'package:http/http.dart' as http;
  import 'dart:convert';
  import '../models/article.dart';
  import '../models/paginated_response.dart';
  import '../models/filter_params.dart';
  import '../utils/constants.dart';
  import '../utils/error_handler.dart';
  ```

- [ ] **Step 2: Add paginated fetch method**
  Replace the fetchArticles method with a paginated version:
  ```dart
  /// Fetch articles with pagination and filtering
  Future<PaginatedResponse> fetchArticles({FilterParams? params}) async {
    final filterParams = params ?? const FilterParams.defaults();
    final url = filterParams.buildUrl(AppConfig.workerApiUrl);

    debugPrint('[Worker] Fetching articles from $url');

    try {
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(
            Duration(seconds: AppConfig.workerTimeoutSeconds),
            onTimeout: () {
              ErrorHandler.logError(
                'Worker API timeout after ${AppConfig.workerTimeoutSeconds}s',
                severity: ErrorSeverity.high,
              );
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final paginatedResponse = PaginatedResponse.fromJson(json);
        debugPrint('[Worker] Fetched ${paginatedResponse.items.length} articles (total: ${paginatedResponse.total})');
        return paginatedResponse;
      } else {
        ErrorHandler.logError(
          'Worker API returned ${response.statusCode}',
          severity: ErrorSeverity.high,
        );
        throw Exception('HTTP ${response.statusCode}');
      }
    } on FormatException catch (e) {
      ErrorHandler.logError(
        'Invalid JSON response from Worker',
        error: e,
        severity: ErrorSeverity.high,
      );
      throw Exception('Invalid JSON response');
    } catch (e) {
      ErrorHandler.logError(
        'Failed to fetch from Worker API',
        error: e,
        severity: ErrorSeverity.high,
      );
      rethrow;
    }
  }

  /// Fetch all articles as a list (backwards compatible)
  Future<List<Article>> fetchArticlesList() async {
    final response = await fetchArticles();
    return response.items;
  }
  ```

- [ ] **Step 3: Add sources endpoint method**
  ```dart
  /// Fetch available sources from Worker
  Future<List<Map<String, dynamic>>> fetchSources() async {
    final sourcesUrl = '${AppConfig.workerApiUrl}sources';
    debugPrint('[Worker] Fetching sources from $sourcesUrl');

    try {
      final response = await _httpClient
          .get(Uri.parse(sourcesUrl))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Sources request timeout');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final sources = (json['sources'] as List<dynamic>)
            .map((s) => s as Map<String, dynamic>)
            .toList();
        debugPrint('[Worker] Fetched ${sources.length} sources');
        return sources;
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(
        'Failed to fetch sources',
        error: e,
        severity: ErrorSeverity.medium,
      );
      rethrow;
    }
  }
  ```

- [ ] **Step 4: Add full-content fetch method**
  ```dart
  /// Fetch full content for an article
  Future<Map<String, dynamic>?> fetchFullContent(String articleUrl) async {
    final encodedUrl = Uri.encodeComponent(articleUrl);
    final contentUrl = '${AppConfig.workerApiUrl}full-content?url=$encodedUrl';

    debugPrint('[Worker] Fetching full content');

    try {
      final response = await _httpClient
          .get(Uri.parse(contentUrl))
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Full content request timeout');
            },
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('[Worker] Fetched full content (${json['wordCount']} words)');
        return json;
      } else if (response.statusCode == 400) {
        // Invalid URL or missing parameter
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(json['error'] ?? 'Invalid request');
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      ErrorHandler.logError(
        'Failed to fetch full content',
        error: e,
        severity: ErrorSeverity.medium,
      );
      return null;
    }
  }
  ```

- [ ] **Step 5: Write/update tests**
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:http/http.dart' as http;
  import 'package:http/testing.dart';
  import 'package:curated_feeds/services/worker_feed_service.dart';
  import 'package:curated_feeds/models/filter_params.dart';

  void main() {
    group('WorkerFeedService', () {
      late WorkerFeedService service;
      late MockClient mockClient;

      setUp(() {
        mockClient = MockClient((request) async {
          final url = request.url.toString();

          if (url.contains('/sources')) {
            return http.Response(
              '{"sources":[{"id":"techcrunch","name":"TechCrunch","category":"Tech"}]}',
              200,
            );
          }

          if (url.contains('/full-content')) {
            return http.Response(
              '{"content":"Full article text","wordCount":500,"fetchedAt":"2024-01-01"}',
              200,
            );
          }

          if (url.contains('category=Tech')) {
            return http.Response(
              '{"items":[],"total":0,"page":1,"pageSize":50,"hasMore":false}',
              200,
            );
          }

          // Default articles response
          return http.Response(
            '{"items":[{"id":"1","title":"Test","description":"Desc","fullContent":"","link":"https://example.com","sourceId":"techcrunch","sourceName":"TechCrunch","sourceCategory":"Tech","sourceColor":"#3B82F6","sourceIcon":"rocket","pubDate":1704067200000}],"total":1,"page":1,"pageSize":50,"hasMore":false}',
            200,
          );
        });

        service = WorkerFeedService(httpClient: mockClient);
      });

      test('should fetch articles with pagination', () async {
        final response = await service.fetchArticles();

        expect(response.items.length, 1);
        expect(response.total, 1);
        expect(response.page, 1);
        expect(response.hasMore, false);
      });

      test('should fetch articles with filter params', () async {
        final params = FilterParams(category: 'Tech', pageSize: 10);
        final response = await service.fetchArticles(params: params);

        expect(response.page, 1);
      });

      test('should fetch sources', () async {
        final sources = await service.fetchSources();

        expect(sources.length, 1);
        expect(sources[0]['id'], 'techcrunch');
      });

      test('should fetch full content', () async {
        final content = await service.fetchFullContent('https://example.com/article');

        expect(content?['wordCount'], 500);
        expect(content?['content'], 'Full article text');
      });

      test('should return null on full content error', () async {
        mockClient = MockClient((request) async {
          return http.Response('{"error":"Failed"}', 500);
        });
        service = WorkerFeedService(httpClient: mockClient);

        final content = await service.fetchFullContent('https://example.com');

        expect(content, null);
      });
    });
  }
  ```

- [ ] **Step 6: Run tests**
  Run: `flutter test test/unit/services/worker_feed_service_test.dart`
  Expected: 6 tests passing

- [ ] **Step 7: Commit**
  ```bash
  git add lib/services/worker_feed_service.dart test/unit/services/worker_feed_service_test.dart
  git commit -m "feat(service): add pagination, filtering, sources, and full-content to WorkerFeedService"
  ```

---

## Task 8: Deploy Updated Worker to Cloudflare

**Files:**
- Modify: `workers/feed-worker.js` (already modified)

**Context:** Deploy the updated worker to production.

- [ ] **Step 1: Verify wrangler.toml exists**
  Check: `cat workers/wrangler.toml`
  Expected: Contains worker name and compatibility date

- [ ] **Step 2: Deploy to Cloudflare**
  Run: `cd workers && npx wrangler deploy`
  Expected: "Successfully published your script..."

- [ ] **Step 3: Test deployed endpoints**
  Test: `curl "https://curated-feeds-worker.raj15400881.workers.dev/?page=1&pageSize=5&category=Tech"`
  Expected: JSON paginated response with filtered Tech articles

  Test: `curl "https://curated-feeds-worker.raj15400881.workers.dev/sources"`
  Expected: JSON with array of sources

  Test: `curl "https://curated-feeds-worker.raj15400881.workers.dev/full-content?url=https://example.com"`
  Expected: JSON with extracted content or error

- [ ] **Step 4: Commit (if any wrangler changes)**
  Check: `git status`
  If changes: `git add workers/wrangler.toml && git commit -m "chore: update worker deployment"`

---

## Task 9: Update ArticleRepository to Use Enhanced WorkerFeedService

**Files:**
- Modify: `lib/repositories/article_repository.dart:64-117`

**Context:** The `fetchNewArticles` method needs to work with the paginated response.

- [ ] **Step 1: Update fetchNewArticles to handle paginated response**
  ```dart
  /// Fetch new articles from Worker API and merge with existing
  /// Now returns ALL articles from all pages
  Future<Result<List<Article>>> fetchNewArticles() async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching new articles from Worker API');

      // Fetch all pages
      final allArticles = <Article>[];
      int page = 1;
      bool hasMore = true;

      while (hasMore && page <= 5) {  // Limit to 5 pages (250 articles max)
        final response = await _workerFeedService.fetchArticles(
          params: FilterParams(page: page, pageSize: 50),
        );

        allArticles.addAll(response.items);
        hasMore = response.hasMore;
        page++;

        if (response.items.isEmpty) break;
      }

      if (allArticles.isEmpty) {
        return Result.success([]);
      }

      // Get existing articles
      final existingResult = await fetchAllArticles();
      if (existingResult.isFailure) {
        return existingResult;
      }

      final existingArticles = existingResult.data ?? [];
      final existingIds = existingArticles.map((a) => a.id).toSet();

      // Filter out duplicates
      final articlesToAdd = allArticles
          .where((a) => !existingIds.contains(a.id))
          .toList();

      if (articlesToAdd.isEmpty) {
        ErrorHandler.logError(
          'No new articles found',
          severity: ErrorSeverity.low,
        );
        return Result.success(existingArticles);
      }

      // Merge and sort
      final mergedArticles = [...existingArticles, ...articlesToAdd];
      mergedArticles.sort((a, b) => b.pubDate.compareTo(a.pubDate));

      // Update cache and save
      _cachedArticles = mergedArticles;
      await _storageService.saveArticles(mergedArticles);

      ErrorHandler.logError(
        'Added ${articlesToAdd.length} new articles. Total: ${mergedArticles.length}',
        severity: ErrorSeverity.low,
      );

      return Result.success(mergedArticles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch new articles',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
  ```

- [ ] **Step 2: Add method for filtered fetch**
  ```dart
  /// Fetch articles with specific filter parameters
  Future<Result<List<Article>>> fetchArticlesWithFilters(FilterParams params) async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching articles with filters');

      final response = await _workerFeedService.fetchArticles(params: params);

      return Result.success(response.items);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch articles with filters',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
  ```

- [ ] **Step 3: Add method to fetch available sources**
  ```dart
  /// Fetch available sources from Worker
  Future<Result<List<Map<String, dynamic>>>> fetchAvailableSources() async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching available sources');

      final sources = await _workerFeedService.fetchSources();
      return Result.success(sources);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch sources',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
  ```

- [ ] **Step 4: Add method to fetch full content**
  ```dart
  /// Fetch full article content
  Future<Result<Map<String, dynamic>?>> fetchArticleFullContent(String articleUrl) async {
    try {
      ErrorHandlerExtensions.logInfo('Fetching full content for article');

      final content = await _workerFeedService.fetchFullContent(articleUrl);

      if (content == null) {
        return Result.failure('Failed to fetch full content');
      }

      return Result.success(content);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch full content',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
  ```

- [ ] **Step 5: Commit**
  ```bash
  git add lib/repositories/article_repository.dart
  git commit -m "feat(repository): update ArticleRepository to use paginated Worker API"
  ```

---

## Task 10: Final Integration Test

**Files:**
- All modified files

**Context:** Run integration test to ensure everything works together.

- [ ] **Step 1: Verify all imports are correct**
  Run: `flutter analyze`
  Expected: No errors

- [ ] **Step 2: Run all unit tests**
  Run: `flutter test`
  Expected: All tests passing

- [ ] **Step 3: Integration check**
  - Worker is deployed with new endpoints
  - Flutter models are created
  - Service is updated
  - Repository is updated

- [ ] **Step 4: Final commit if needed**
  Check: `git status`

---

## Summary

After completing these tasks, the system will have:

1. **Cloudflare Worker with:**
   - Pagination support (`?page=1&pageSize=50`)
   - Category filtering (`?category=Tech`)
   - Source filtering (`?source=techcrunch,verge`)
   - Search (`?q=artificial+intelligence`)
   - Date range (`?since=2024-01-01&until=2024-12-31`)
   - Sorting (`?sort=date_desc|date_asc|source`)
   - `/sources` endpoint for source metadata
   - `/full-content?url=` endpoint for article extraction

2. **Flutter models:**
   - `PaginatedResponse` - typed pagination wrapper
   - `FilterParams` - query parameter builder

3. **Enhanced services:**
   - Updated `WorkerFeedService` with all new methods
   - Backwards compatible `fetchArticlesList()` method

4. **Repository updates:**
   - Paginated article fetching
   - Filtered fetch support
   - Source discovery
   - Full content fetching
