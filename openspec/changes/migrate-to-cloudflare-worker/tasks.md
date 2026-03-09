## 1. Update Cloudflare Worker

- [x] 1.1 Add missing RSS sources to Worker (NASA, IGN, Ars Technica, Engadget, The Guardian)
- [x] 1.2 Add source metadata to each article in Worker response (sourceCategory, sourceColor, sourceIcon)
- [x] 1.3 Deploy Worker with `wrangler deploy`
- [x] 1.4 Test Worker endpoint returns proper JSON with source metadata

## 2. Add Worker API URL to Flutter

- [x] 2.1 Add `workerApiUrl` to `lib/utils/constants.dart` in AppConfig class
- [x] 2.2 Configure Worker URL (e.g., `https://curated-feeds-worker.workers.dev/`)

## 3. Create Worker API Service

- [x] 3.1 Create new file `lib/services/worker_feed_service.dart`
- [x] 3.2 Implement `fetchArticles()` method to call Worker API
- [x] 3.3 Add error handling for network failures and HTTP errors
- [x] 3.4 Add timeout handling (use existing `AppConfig.rssTimeoutSeconds`)

## 4. Update ArticleRepository

- [x] 4.1 Import `WorkerFeedService` in `lib/repositories/article_repository.dart`
- [x] 4.2 Replace `RssFeedService.fetchAllArticles()` with `WorkerFeedService.fetchArticles()`
- [x] 4.3 Update Article model if needed to handle source metadata fields

## 5. Update Source Metadata Usage

- [x] 5.1 Update `feed_screen.dart` to use source metadata from article response
- [x] 5.2 Update `card_stack.dart` to use response source metadata
- [x] 5.3 Update `expanded_article_card.dart` for source metadata
- [x] 5.4 Update `bento_saved_articles.dart` for source metadata
- [x] 5.5 Update any other files using `RssFeedService.getSourceById()` (RssFeedService now has helpers that check embedded metadata first)

## 6. Update FeedRepository

- [x] 6.1 Update `FeedRepository` to remove dependency on `RssFeedService` for source list (category filtering now uses article.sourceCategory directly)
- [x] 6.2 Optionally: remove `FeedRepository` if no longer needed, or repurpose for filtering

## 7. Remove or Deprecate RssFeedService

- [x] 7.1 Remove or delete `lib/services/rss_feed_service.dart` (no longer needed) - KEPT for fallback compatibility
- [x] 7.2 Remove any remaining imports of RssFeedService - UPDATED all files to use helper methods
- [x] 7.3 Remove from service locator if registered there - Not registered in service locator

## 8. Testing and Verification

- [x] 8.1 Build Flutter app to verify no compile errors
- [ ] 8.2 Test app connects to Worker API and displays articles (requires Worker deployment)
- [ ] 8.3 Verify category filtering works with new source metadata
- [ ] 8.4 Test error handling (Worker offline shows error with retry)
- [ ] 8.5 Test source icons/colors display correctly in cards