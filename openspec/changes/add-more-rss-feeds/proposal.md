## Why

The app currently has only 6 RSS feed sources (The Verge, Wired, BBC, New Scientist, Sky Sports, Variety). Adding more image-friendly RSS feeds will increase content diversity and provide users with more fresh articles to browse. Rich image content improves the visual appeal of the article cards.

## What Changes

- Add 6 new image-friendly RSS feed sources across Tech, News, and Gaming categories
- New Tech sources: Ars Technica, TechCrunch (re-adding), Engadget
- New News source: The Guardian
- New Gaming source: IGN
- New Science source: NASA
- No breaking changes - purely additive

## Capabilities

### New Capabilities
- `rss-feed-sources`: Add new RSS feed sources to the feed configuration
- `rss-feed-categories`: Add new category colors for Gaming

### Modified Capabilities
- None - no existing requirements change

## Impact

- **Files Modified**:
  - `lib/services/rss_feed_service.dart` - Add new RSS source definitions
  - `lib/utils/constants.dart` - Add new category colors for Gaming
- **No new dependencies or breaking changes**