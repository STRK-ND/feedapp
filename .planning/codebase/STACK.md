# Technology Stack

**Analysis Date:** 2026-02-22

## Languages

**Primary:**
- Dart 3.10.8+ - Used for all application code in `lib/` directory

**Native (Platform-specific):**
- Kotlin - Android native code in `android/app/src/main/kotlin/` (if present)
- Swift - iOS native code in `ios/Runner/AppDelegate.swift`
- Objective-C - iOS plugin registration in `ios/Runner/GeneratedPluginRegistrant.m`

## Runtime

**Environment:**
- Flutter SDK - Cross-platform UI framework revision 67323de285b (stable channel)

**Package Manager:**
- Flutter pub - Dart package manager
- Lockfile: present (`pubspec.lock` in project root)

## Frameworks

**Core:**
- Flutter ^3.x - Cross-platform UI framework for mobile, desktop, and web
- Material3 Design - UI component library (uses-material-design: true)

**Testing:**
- flutter_test - Built-in Flutter testing framework
- mockito ^5.6.3 - Mocking library for unit tests
- build_runner ^2.11.1 - Code generation for tests

**Build/Dev:**
- flutter_lints ^6.0.0 - Dart/Flutter linting rules
- Google Fonts ^8.0.1 - Typography system

## Key Dependencies

**Critical:**
- http ^1.2.0 - HTTP client for fetching RSS feeds and article content
- xml ^6.3.0 - XML parsing for RSS feed processing
- html ^0.15.4 - HTML parsing for article content extraction
- get_it ^7.6.4 - Service locator for dependency injection

**Infrastructure:**
- flutter_secure_storage ^10.0.0 - Secure local storage for articles and preferences
- shared_preferences ^2.3.4 - Key-value storage for user preferences
- flutter_cache_manager ^3.3.1 - Disk caching for images and content
- cached_network_image ^3.3.0 - Image caching and display
- connectivity_plus ^7.0.0 - Network connectivity monitoring

**UI/UX:**
- cupertino_icons ^1.0.8 - iOS-style icons
- url_launcher ^6.2.0 - Opening links in external browser
- share_plus ^12.0.1 - Sharing content to other apps
- open_filex ^4.7.0 - Opening files with system handlers
- package_info_plus ^9.0.0 - App version and build info
- path_provider ^2.1.4 - File system path access
- permission_handler ^12.0.1 - Runtime permission requests

## Configuration

**Environment:**
- No external configuration files (.env files not detected)
- Configuration via `lib/utils/constants.dart` - App-wide constants
- RSS feed sources configured in `lib/providers/feed_providers.dart`

**Build:**
- `pubspec.yaml` - Flutter project manifest and dependency declarations
- `analysis_options.yaml` - Dart analyzer and linting configuration
- Strong mode enabled with implicit-casts: false, implicit-dynamic: false
- Custom lint rules: prefer_const_constructors, prefer_final_fields, use_key_in_widget_constructors

**Platform-specific configs:**
- `android/app/build.gradle.kts` - Android build configuration (compileSdk, minSdk, targetSdk from Flutter)
- `android/app/src/main/AndroidManifest.xml` - Android app manifest
- `ios/Runner/Info.plist` - iOS app configuration
- `.metadata` - Flutter project type and version tracking

## Platform Requirements

**Development:**
- Flutter SDK 3.x (stable channel)
- Dart SDK >=3.10.8
- Android SDK (for Android builds)
- Xcode (for iOS builds - macOS only)
- Android Studio or VS Code with Flutter plugin

**Production:**
- App version: 1.2.0+7 (versionName: 1.2.0, versionCode: 7)
- Multi-platform deployment: Android, iOS, Windows, Linux, macOS, Web
- Android package: com.curatedfeeds
- Minimum Android SDK: Flutter default (configured in build.gradle.kts)

---

*Stack analysis: 2026-02-22*
