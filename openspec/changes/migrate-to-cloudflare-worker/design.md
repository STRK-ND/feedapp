## Context

The Flutter app currently uses `RssFeedService` to:
1. Fetch RSS XML from 12 predefined sources directly from the client
2. Parse RSS XML into Article objects on-device
3. Provide source metadata (category, color, icon) for UI display

A Cloudflare Worker exists at `workers/feed-worker.js` that:
- Fetches from 9 RSS sources
- Parses XML on the server
- Returns JSON with article data
- Has built-in caching (15 min TTL)

**Current architecture:**
```
Flutter App → RssFeedService → HTTP to RSS sources → Parse XML → Display
```

**Target architecture:**
```
Flutter App → HTTP GET Worker API → JSON Response → Display
              (Worker fetches & parses RSS)
```

## Goals / Non-Goals

**Goals:**
- Remove RSS fetching and XML parsing from the Flutter client
- Use existing Cloudflare Worker as the sole feed fetching endpoint
- Ensure UI still displays source metadata (category, color, icon)
- Handle Worker unavailability gracefully with fallback

**Non-Goals:**
- This is not a new feature - it's a refactoring
- No changes to article storage, saved articles, or offline mode
- No changes to the article detail view or content fetching
- Not implementing push notifications for new articles

## Decisions

### 1. Worker API URL Configuration

**Decision:** Add worker URL to `lib/utils/constants.dart` as `AppConfig.workerApiUrl`

**Rationale:** Constants file already holds configuration like timeouts. Single place to update.

**Alternative:** Environment variable at build time - too complex for a simple URL.

### 2. Source Metadata Strategy

**Decision:** Embed source metadata in Worker response

The Worker will return each article with:
```json
{
  "id": "...",
  "title": "...",
  "sourceId": "techcrunch",
  "sourceName": "TechCrunch",
  "sourceCategory": "Tech",
  "sourceColor": "#3B82F6",
  "sourceIcon": "rocket_launch",
  ...
}
```

**Rationale:**
- Single API call returns everything needed
- Easier to sync sources - change in one place (Worker)
- Flutter doesn't need to maintain parallel source list

**Alternative considered:** Keep a separate Dart file with source metadata - rejected because it creates duplication.

### 3. Error Handling

**Decision:** On Worker failure, show error message and allow retry. Do not fall back to direct RSS.

**Rationale:** Direct RSS fetching is what we're removing - if Worker fails, we want to know, not silently bypass it.

**Alternative considered:** Fallback to direct RSS - would require keeping RssFeedService code, defeating the purpose.

### 4. Source List Sync

**Decision:** Use the union of Worker and Flutter sources, consolidated in Worker

Sources to include in Worker:
- Tech: TechCrunch, The Verge, Wired, Ars Technica, Engadget
- News: BBC World, The Guardian
- Science: New Scientist, NASA
- Sports: Sky Sports
- Entertainment: Variety
- Gaming: IGN

**Rationale:** Worker is now the source of truth for sources. Flutter just displays what Worker returns.

## Risks / Trade-offs

**[Risk] Worker downtime affects entire app**
→ Mitigation: Show user-friendly error with retry button. Cache previously fetched articles in local storage.

**[Risk] Worker response size larger than individual RSS**
→ Mitigation: Worker already has 15-min caching. Response is JSON, typically smaller than full XML.

**[Risk] Source metadata in Worker is harder to maintain**
→ Mitigation: Source config is a simple array in the Worker - easy to edit in one place.

**[Risk] Image URLs from Worker may differ from what client would extract**
→ Mitigation: Accept Worker-provided image URLs as-is. Image extraction logic stays in Worker.

## Migration Plan

1. **Update Worker** (`workers/feed-worker.js`):
   - Add source metadata (category, color, icon) to each article
   - Add missing sources to RSS_SOURCES array
   - Deploy with `wrangler deploy`

2. **Update Flutter App**:
   - Add `AppConfig.workerApiUrl` to constants
   - Create new service to call Worker API
   - Update `ArticleRepository.fetchNewArticles()` to use new service
   - Update UI components to use source metadata from response
   - Remove `RssFeedService` (or keep for source metadata only)

3. **Deploy**:
   - Deploy Worker first
   - Then deploy Flutter app update
   - Monitor for any API errors

## Open Questions

1. **Should we add a `/sources` endpoint to Worker?**
   - Could be useful for showing available sources in settings
   - Not strictly necessary for MVP

2. **Should we add analytics to track Worker API performance?**
   - Nice to have but not required
   - Can add later via Firebase Analytics

3. **What about the Science category?**
   - Currently includes NASA but Worker only has 9 sources
   - Will add NASA to Worker in the update