## Why

The Flutter app currently fetches RSS feeds directly from client devices, making HTTP requests to multiple RSS sources and parsing XML on-device. This approach has significant drawbacks: increased battery/data usage on mobile devices, inconsistent caching, no centralized source management, and the app must handle XML parsing overhead. We already have a Cloudflare Worker (`workers/feed-worker.js`) that fetches and parses RSS feeds, but it's not integrated. Migrating to the Worker consolidates feed fetching to the server edge, reduces client-side work, and provides built-in caching.

## What Changes

- **Remove** `RssFeedService` from the Flutter app (currently handles RSS fetching + XML parsing)
- **Add** HTTP client to call Cloudflare Worker API for fetching articles
- **Keep** source metadata (RssSource model with category, color, icon) - either in Dart or embedded in Worker response
- **Update** `ArticleRepository.fetchNewArticles()` to call Worker API instead of `RssFeedService.fetchAllArticles()`
- **Update** `FeedRepository` to source metadata from the new location
- **Add** error handling and fallback mechanism if Worker is unavailable
- **Sync** RSS source list between Worker (9 sources) and Flutter app (12 sources)

## Capabilities

### New Capabilities

- `cloudflare-worker-api`: External API capability to fetch articles from the Cloudflare Worker endpoint instead of direct RSS fetching. This includes configuring the worker URL, handling the JSON response, and managing caching/error scenarios.

- `source-metadata`: A capability to provide RSS source metadata (category, color, icon, name) for display in the UI. This can either come from the Worker response (embedded) or from a simplified Dart file containing only source metadata without fetching logic.

### Modified Capabilities

None - this is a pure refactoring with no change to existing requirements.

## Impact

- **Code**: `lib/services/rss_feed_service.dart` will be removed or replaced. Updates to `lib/repositories/article_repository.dart`, `lib/repositories/feed_repository.dart`.
- **APIs**: App will call Cloudflare Worker endpoint (e.g., `https://curated-feeds-worker.workers.dev/`) instead of direct RSS URLs.
- **Workers**: The existing `workers/feed-worker.js` must be updated to include source metadata in responses.
- **Build**: No new dependencies, just using Dart's built-in `http` package (already present).