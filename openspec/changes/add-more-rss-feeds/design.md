## Context

The app currently uses 6 RSS feed sources stored in `lib/services/rss_feed_service.dart`. Each source is a `RssSource` object with id, name, url, category, color, and icon. The goal is to add more image-friendly sources to increase content diversity.

## Goals / Non-Goals

**Goals:**
- Add 6 new RSS feed sources with good image support
- Ensure all new sources have reliable RSS feeds with image metadata
- Add Gaming category color for the new IGN feed source
- Maintain the existing architecture - no refactoring

**Non-Goals:**
- Add user-configurable RSS sources (future work)
- Remove any existing sources
- Change the RSS parsing logic

## Decisions

1. **Which sources to add?**
   - Ars Technica (Tech) - Known for excellent image support in RSS
   - TechCrunch (Tech) - Was previously removed, re-adding due to user request
   - Engadget (Tech) - Reliable, good thumbnails
   - The Guardian (News) - Strong international news with images
   - IGN (Gaming) - Massive gaming coverage with great images
   - NASA (Science) - Space news with excellent image quality

2. **Where to add new category colors?**
   - Add Gaming category color to `lib/utils/constants.dart`
   - Use purple/violet shade to match existing category palette

3. **Image-friendly criteria**
   - Sources with `<enclosure>` tags for images
   - Sources with `media:content` or `media:thumbnail` elements
   - Sources with `content:encoded` that include `<img>` tags

## Risks / Trade-offs

- [Risk] Some RSS feeds may change or break → Mitigation: Use well-established sources with stable feeds
- [Risk] More sources = longer fetch time → Mitigation: Parallel fetching already implemented, timeout limits in place
- [Risk] New category (Gaming) may not have existing UI support → Mitigation: Will add category color to constants

## Open Questions

None - all technical decisions are straightforward additions.