## Context

Current app displays multiple RSS feed sources including TechCrunch, Nature, and ESPN, and has a Science category tab in the navigation. User has requested these be hidden/removed to simplify the feed.

## Goals / Non-Goals

**Goals:**
- Remove TechCrunch RSS source from the feed configuration
- Remove Nature RSS source from the feed configuration
- Remove ESPN RSS source from the feed configuration
- Remove Science category from the tab navigation

**Non-Goals:**
- No new features or capabilities
- No changes to the RSS feed fetching mechanism
- No changes to data storage or API contracts

## Decisions

This is a straightforward removal task with no architectural decisions required. The implementation simply involves:
1. Removing source definitions from `rss_feed_service.dart`
2. Removing Science category from `constants.dart`

**Alternative considered:** Could add a "hidden" flag to sources instead of removing them. However, since the user explicitly requested hiding these sources, complete removal is cleaner and reduces code complexity.

## Risks / Trade-offs

- **Low risk**: Simple code removal, no impact on existing functionality
- **No rollback needed**: Easy to re-add sources if needed later