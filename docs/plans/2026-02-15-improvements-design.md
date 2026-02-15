# Curated Feeds - Incremental Enhancement Design

**Date**: 2026-02-15
**Project**: Flutter RSS Reader App (Curated Feeds)
**Approach**: Incremental Enhancement (Phase-by-phase improvement)

## Overview

This document outlines a systematic, incremental enhancement plan for the Curated Feeds Flutter RSS reader application. The approach focuses on gradual architectural improvements while delivering user-visible improvements at each phase.

## Architecture

### Target Architecture (Layered)

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                      │
│  (Widgets, Screens - Existing Flutter UI code)                │
└─────────────────────────────────────────────────────────────┘
                          ↑↓
┌─────────────────────────────────────────────────────────────┐
│                     Business Logic Layer                    │
│  (New: Controllers/ViewModels and Repository Pattern)        │
└─────────────────────────────────────────────────────────────┘
                          ↑↓
┌─────────────────────────────────────────────────────────────┐
│                         Data Layer                          │
│  (Existing: Services - RSS, Storage, Cache, etc.)            │
└─────────────────────────────────────────────────────────────┘
                          ↑↓
┌─────────────────────────────────────────────────────────────┐
│                         Data Sources                        │
│  (HTTP, Secure Storage, Local Cache)                         │
└─────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

1. **Repository Pattern**: Abstract data operations from services to improve testability and enable easier data source changes
2. **State Evolution**: Maintain setState-based approach initially, gradually introduce simple state management as complexity grows
3. **Dependency Injection**: Introduce get_it service locator for better testability and reduced coupling
4. **Separation of Concerns**: Extract business logic from widgets into separate classes progressively

## Data Flow

### Enhanced Data Flow

```
User Action → Widget → Controller → Repository → Service → Data Source
                                            ↓
                                      Data Cache
                                            ↓
                                    Return Model → State Update → UI Refresh
```

### Caching Strategy

- **Layer 1**: In-memory cache (immediate access)
- **Layer 2**: Secure storage (persistent across app restarts)
- **Layer 3**: Network fetch (source of truth)

### Error Handling Flow

```
Operation Attempt → Repository catches → ErrorHandler logs
       ↓ (success)                    ↓ (failure)
   Return Result<T>               Return User-friendly message
       ↓                           ↓
   UI updates                     UI shows error banner
```

### Offline First Pattern

- Always show cached data first
- Background refresh when online
- Graceful degradation when offline

### Data Transformation Strategy

- Raw API data (XML/JSON) → Domain Models → UI Models
- Each layer transforms only what it needs
- Consistent data validation at repository level

## Component Organization

### Phase 1: Current Structure (Preserved)

```
lib/
├── models/              # Domain models
│   ├── article.dart
│   └── rss_source.dart
├── services/            # Data layer
│   ├── rss_feed_service.dart
│   ├── storage_service.dart
│   ├── cache_manager.dart
│   └── update_service.dart
├── widgets/             # Reusable widgets
│   ├── card_stack.dart
│   ├── swipeable_card.dart
│   └── expanded_article_card.dart
├── screens/             # Screen widgets
│   └── feed_screen.dart
└── utils/               # Utilities
    ├── constants.dart
    ├── helpers.dart
    └── error_handler.dart
```

### Phase 2: Add Repository Layer

```
lib/
├── repositories/        # NEW: Data access abstraction
│   ├── article_repository.dart
│   └── feed_repository.dart
└── di/                  # NEW: Dependency injection
    └── service_locator.dart
```

### Phase 3: Add Controllers

```
lib/
├── controllers/         # NEW: Business logic
│   ├── feed_controller.dart
│   └── article_controller.dart
```

### Phase 4: Add Testing Structure

```
test/
├── unit/
│   ├── repositories/
│   ├── controllers/
│   └── utils/
└── widget/
    └── widgets/
```

### Migration Strategy

1. Keep existing structure intact
2. Add new layers alongside
3. Migrate one feature at a time
4. Remove old code only after migration is verified

## Error Handling

### Error Classification System

```
Network Errors (recoverable):
├── Timeout → Show retry button
├── Offline → Show cached + offline banner
└── Rate Limit → Show "try again later"

Data Errors (partial recovery):
├── Invalid XML → Skip article, log warning
├── Missing image → Show placeholder
└── Corrupt cache → Clear and re-fetch

Critical Errors (app-level):
├── Parse failure → Show error screen
├── Storage error → Graceful degradation
└── Crash → Restart app with safe state
```

### Error Recovery Mechanics

- **Retry Policy**: Exponential backoff (1s → 2s → 4s)
- **Fallback Content**: Always have cached content as backup
- **User Action**: Clear retry/countdown UI for user control

## Testing

### Test Pyramid

```
           /\
          /  \         (5%) - Critical user flows only
         / E2E \
        /--------\
       / Integration\  (20%) - Repository + Service integration
      /     Tests    \
     /----------------\
    /   Unit Tests    \ (75%) - Models, Utils, Controllers
   /------------------\
```

### Testing Priorities by Phase

**Phase 1 (Early):**
- Model validation (fromJson/toJson)
- Utility functions (Helpers class)
- Date formatting and text transformations

**Phase 2 (Mid):**
- Repository layer operations
- Cache management
- Error handling scenarios

**Phase 3 (Later):**
- Controller business logic
- State management transitions
- Widget integration tests

### Testing Tools

- `flutter_test` for unit and widget tests
- `mockito` for mocking services
- `integration_test` for E2E flows

## UX Improvements

### Visual Enhancements

**Dark Mode Support**
- Dynamic theme switcher
- Adaptive color palette based on luminance
- WCAG AA compliant contrast ratios

**Custom RSS Feeds**
- URL input with auto-detection
- Custom categories with color picker
- Feed health status indicator
- Pin/unpin favorite sources

**Search & Filter Improvements**
- Real-time search with debounce (300ms)
- Search by title, description, source, or content
- Save search filters as "Smart Collections"
- Recent searches with history
- Advanced filters (date range, source, read status)

### User Experience Improvements

**Pull-to-Refresh Enhancements**
- Visual progress indicator per source
- Show which sources are updating
- Refresh completion summary

**Offline Experience**
- Download articles for offline reading (manual trigger)
- Sync indicators showing what's cached
- Bandwidth-aware article loading

**Article Reading Experience**
- Reader mode (text-only view)
- Font size adjustment
- Article highlights/bookmarks
- Reading progress indicator

**Notifications**
- Batch updates (once per day max)
- Smart notification timing based on user activity
- Category-based notification preferences

### Performance UX

- Skeleton loaders instead of spinners
- Staggered animations for smoother feel
- Image lazy loading with progressive quality
- Swipe gesture feedback improvements

## Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal**: Establish the repository layer and improve testing foundation

- Introduce repository pattern
- Add dependency injection setup
- Add unit tests for models and utils
- Improve error handling with better categorization

**Deliverables**: Tests passing, repositories wired up, no breaking UI changes

---

### Phase 2: Core Features Enhancement (Week 3-4)

**Goal**: Improve search, caching, and offline experience

- Enhanced search with real-time filtering
- Better caching strategy with memory management
- Offline-first improvements
- Article content fetching improvements

**Deliverables**: Faster search, better offline experience, reduced memory usage

---

### Phase 3: UI/UX Improvements (Week 5-6)

**Goal**: Add dark mode and enhance visual feedback

- Dark mode implementation with system preference detection
- Improved pull-to-refresh with source-level feedback
- Skeleton loaders for smoother UX
- Better empty states and error screens

**Deliverables**: Dark mode functional, smoother UI transitions

---

### Phase 4: User Customization (Week 7-8)

**Goal**: Add custom RSS feeds and reading preferences

- Custom feed CRUD operations
- Feed categories management
- Reading preferences (font size, theme tweaks)
- Smart collections for saved searches

**Deliverables**: Users can add custom feeds, sync preferences

---

### Phase 5: Advanced Features (Week 9-10)

**Goal**: Final polish and advanced functionality

- Reader mode for distraction-free reading
- Article highlighting/bookmarks
- Background sync with notification batching
- Final bug fixes and optimizations

**Deliverables**: Production-ready enhanced app

---

### Phase 6: Maintenance & Future (Ongoing)

- Monitoring and crash reporting integration
- Performance analytics
- User feedback collection
- Future feature planning

## Success Criteria

- Each phase can be shipped independently
- Test coverage increases progressively
- User experience improves at each delivery
- Technical debt decreases over time
- No major breaking changes to existing functionality

## Notes

- Codebase analysis shows good existing structure with proper separation of concerns
- Current services (rss_feed_service, storage_service, cache_manager) are well-organized
- Error handling foundation already exists with ErrorHandler class
- UI components are properly separated into widgets/screens
- Incremental approach allows for course corrections based on user feedback
