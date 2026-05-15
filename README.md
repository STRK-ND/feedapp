# Curated Feeds

A mobile RSS reader built with Flutter. Browse articles from 12 curated sources with a swipeable card interface, save articles for later, and switch between light and dark themes.

## Features

- Swipeable card-based article browsing
- Bento grid layout for saved articles
- Light and dark theme support (Stitch Design System)
- Pull-to-refresh on both card and list views
- Haptic feedback on card interactions
- Cloudflare Worker API + direct RSS feed aggregation

## Project Structure

```
lib/
  models/          # Data models (Article, PaginatedResponse)
  providers/       # State management (FeedProvider, ThemeProvider)
  repositories/    # Data access layer
  screens/         # UI screens (Feed, Saved, Settings)
  services/       # API clients and utilities
  widgets/         # Reusable UI components
```

## Getting Started

1. Install Flutter 3.29+
2. Run `flutter pub get`
3. Run `flutter run`

## Build & Test

```bash
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build apk --debug
```

CI runs on GitHub Actions (`.github/workflows/ci.yml`).
