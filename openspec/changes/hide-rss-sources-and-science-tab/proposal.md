## Why

User request to remove specific RSS sources (TechCrunch, Nature, ESPN) and the Science category tab from the feed. This simplifies the content sources and reduces clutter for users who don't need these specific sources.

## What Changes

- Remove TechCrunch RSS source from the feed configuration
- Remove Nature RSS source from the feed configuration
- Remove ESPN RSS source from the feed configuration
- Hide/remove the Science tab from the category navigation

## Capabilities

### New Capabilities
None - this is a removal/simplification change.

### Modified Capabilities
- `rss-feed-sources`: Remove TechCrunch, Nature, and ESPN from the RSS feed sources list
- `category-tabs`: Remove Science category from the tab navigation

## Impact

- **Files Modified**:
  - `lib/services/rss_feed_service.dart` - Remove RSS source definitions
  - `lib/utils/constants.dart` - Remove Science category from constants
- **No new dependencies or breaking changes**