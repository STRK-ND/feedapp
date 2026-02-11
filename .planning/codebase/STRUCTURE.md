# Codebase Structure

**Analysis Date:** 2026-02-11

## Directory Layout

```
myapp/
├── .github/workflows    # CI/CD workflows
├── .planning/codebase   # Generated codebase documentation
├── android/             # Android platform-specific files
├── ios/                 # iOS platform-specific files
├── lib/                 # Dart source code
├── test/                # Test files
├── web/                 # Web platform-specific files
├── windows/             # Windows platform-specific files
├── linux/               # Linux platform-specific files
├── macos/               # macOS platform-specific files
├── .dart_tool/          # Build artifacts (generated)
├── pubspec.yaml         # Package dependencies and metadata
├── pubspec.lock         # Dependency lock file
└── analysis_options.yaml # Dart static analysis configuration
```

## Directory Purposes

**lib/ (Source Code):**
- Purpose: Contains all Dart application code
- Contains: Widgets, services, data models, business logic
- Key files: `lib/main.dart` (primary monolithic file, all UI and models)

**lib/services/ (Services Layer):**
- Purpose: Isolated business logic for external integrations
- Contains: Update checking, APK downloading
- Key files: `lib/services/update_service.dart`, `lib/services/apk_downloader.dart`

**lib/widgets/ (UI Components):**
- Purpose: Reusable dialog and widget components
- Contains: Update dialog for version notifications
- Key files: `lib/widgets/update_dialog.dart`

**test/ (Tests):**
- Purpose: Unit and widget tests
- Contains: Article model tests, widget integration tests
- Key files: `test/article_test.dart`, `test/widget_test.dart`

**android/, ios/, web/, windows/, linux/, macos/ (Platform):**
- Purpose: Platform-specific configuration and native code
- Contains: Build configuration, app manifests, native code hooks
- Generated: Yes (Flutter generates some files during build)
- Committed: Yes

**.github/workflows/ (CI/CD):**
- Purpose: GitHub Actions workflows
- Contains: Automated build and deployment configurations
- Generated: No (manual configuration)

**.dart_tool/ (Build Artifacts):**
- Purpose: Dart SDK build artifacts and caches
- Contains: Package metadata, build output
- Generated: Yes
- Committed: No

## Key File Locations

**Entry Points:**
- `lib/main.dart`: Application entry point (main() function), all widgets, models, and business logic (2935 lines)

**Configuration:**
- `pubspec.yaml`: Package dependencies, version info, Flutter configuration
- `analysis_options.yaml`: Dart linter rules and static analysis configuration
- `.flutter-plugins-dependencies`: Flutter plugin dependency tracking

**Core Logic:**
- `lib/services/update_service.dart`: GitHub version checking service (162 lines)
- `lib/services/apk_downloader.dart`: APK file download utility (99 lines)
- `lib/widgets/update_dialog.dart`: Update notification dialog widget (199 lines)

**Testing:**
- `test/article_test.dart`: Article model serialization and behavior tests (589 lines)
- `test/widget_test.dart`: Widget integration tests (38 lines)

**Platform-Specific:**
- `android/app/src/main/kotlin/`: Android native code and configuration
- `ios/Runner/`: iOS app configuration and Info.plist

## Naming Conventions

**Files:**
- `main.dart`: Main application entry point
- `_name.dart`: Private local files (not observed in this codebase)
- `<name>.dart`: Public package file
- `<name>_test.dart`: Test file for `<name>.dart`
- `<name>_service.dart`: Service/business logic files
- `<name>_dialog.dart`: Dialog/widget component files

**Directories:**
- `lib/`: Source code
- `test/`: Tests
- `<platform>/`: Platform-specific files (android/, ios/, etc.)

**Classes:**
- PascalCase: `RssReaderApp`, `RssFeedScreen`, `SwipeableCard`, `UpdateService`
- Private classes: `_RssFeedScreenState`, `_CardStackState`, `_SwipeableCardState`, `_AppColors`

## Where to Add New Code

**New Feature:**
- Primary code: `lib/main.dart` (add new widget classes, state, or extend existing classes)
- Tests: `test/` (create new `<feature>_test.dart` file)

**New Component/Module:**
- Implementation: `lib/main.dart` (monolithic structure - no separation enforced)
  - For isolated functionality: Consider extracting to `lib/services/` or `lib/widgets/`
- Example: New utility service → `lib/services/<name>_service.dart`
- Example: New dialog → `lib/widgets/<name>_dialog.dart`

**Utilities:**
- Shared helpers: `lib/main.dart` (add as top-level functions or static methods)
- Complex utilities: Consider `lib/services/` directory for extraction

## Special Directories

**lib/:**
- Purpose: All Dart source code
- Generated: No
- Committed: Yes

**lib/services/:**
- Purpose: Business logic and external integrations
- Generated: No
- Committed: Yes

**lib/widgets/:**
- Purpose: Reusable UI components (dialogs, custom widgets)
- Generated: No
- Committed: Yes

**test/:**
- Purpose: Unit and widget tests
- Generated: No
- Committed: Yes

**.dart_tool/:**
- Purpose: Build artifacts and caches
- Generated: Yes (by Flutter SDK)
- Committed: No

**build/:**
- Purpose: Flutter build output (not present by default, created during builds)
- Generated: Yes
- Committed: No

**.idea/ (for Android Studio/IntelliJ):**
- Purpose: IDE configuration
- Generated: Yes
- Committed: Yes (for team consistency)

## Architectural Notes

**Monolithic Structure:**
- The application follows a monolithic pattern with 2935 lines in `lib/main.dart`
- All data models (Article, RssSource), widgets, state management, and RSS parsing are in a single file
- Minimal separation of concerns - services are the only extracted components

**Recommended Refactoring for New Features:**
1. Extract data models to `lib/models/` directory
2. Separate widgets into `lib/screens/` and `lib/widgets/`
3. Move RSS parsing to `lib/services/rss_service.dart`
4. Consider state management (Provider/Riverpod) for complex interactions

---

*Structure analysis: 2026-02-11*
