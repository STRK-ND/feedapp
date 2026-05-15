# Curated Feeds

RSS reader mobile app built with Flutter.

## Project Overview
- **Platforms:** iOS + Android (web/other platforms removed)
- **Architecture:** Provider for state management, GetIt for dependency injection
- **Data sources:** Cloudflare Worker API + direct RSS feeds (12 curated sources)
- **Storage:** flutter_secure_storage (credentials), shared_preferences (settings), in-memory cache

## Design System
Always read DESIGN.md before making any visual or UI decisions.
All font choices, colors, spacing, and aesthetic direction are defined there.
Do not deviate without explicit user approval.
In QA mode, flag any code that doesn't match DESIGN.md.

## Skill Routing
When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Security audit → invoke /cso
- Design consultation → invoke /design-consultation
- Save progress → invoke /context-save
- Resume context → invoke /context-restore

## Key Files
- `lib/models/article.dart` — Article model with compound ID format (`sourceId:originalId`)
- `lib/services/worker_feed_service.dart` — Cloudflare Worker API client
- `lib/services/rss_feed_service.dart` — Direct RSS feed parser
- `lib/providers/feed_provider.dart` — Main feed state management
- `lib/screens/feed_screen.dart` — Primary feed UI with card stack
- `lib/widgets/card_stack.dart` — Swipeable card stack widget
- `lib/utils/constants.dart` — Colors, spacing, card styles (Stitch Design System)

## Article ID Format
Articles use compound IDs (`sourceId:originalId`) to prevent collisions between the Worker API (numeric IDs) and RSS feeds (link.hashCode IDs). Example: `worker:123`, `verge:9876543`.