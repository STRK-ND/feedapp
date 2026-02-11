# Technology Stack

**Analysis Date:** 2026-02-11

## Languages

**Primary:**
- Dart 3.10.8+ - Core application language, used throughout `lib/` directory

**Secondary:**
- Kotlin 2.2.20 - Android native code in `android/` directory
- Java 17 - Android build compatibility in `android/app/build.gradle.kts`
- Objective-C/Swift - iOS native code in `ios/` directory

## Runtime

**Environment:**
- Flutter 3.38.4+ - Cross-platform UI framework
- Dart SDK >=3.10.8 <4.0.0

**Package Manager:**
- pub (Dart package manager)
- Lockfile: present (`pubspec.lock`)

## Frameworks

**Core:**
- Flutter SDK - Cross-platform UI framework (Android, iOS, Windows, macOS, Linux, Web)
- Material Design 3 - UI component library (`lib/main.dart`)

**Testing:**
- flutter_test - Flutter's built-in testing framework (`test/` directory)

**Build/Dev:**
- Gradle 8+ - Android build system
- GitHub Actions - CI/CD pipeline (`.github/workflows/build.yml`)

## Key Dependencies

**Critical:**
- http ^1.6.0 - HTTP requests for RSS feeds and GitHub API
- xml ^6.6.1 - XML parsing for RSS feeds
- shared_preferences ^2.5.4 - Local key-value storage for app settings
- cached_network_image ^3.4.1 - Image caching with background loading

**Infrastructure:**
- connectivity_plus ^6.1.5 - Network connectivity detection
- path_provider ^2.1.5 - Cross-platform file system access
- permission_handler ^12.0.1 - Runtime permission handling
- package_info_plus ^8.3.1 - App version and metadata
- url_launcher ^6.3.2 - System URL launching (web browser, etc.)
- share_plus ^7.2.2 - Platform sharing functionality
- open_filex ^4.7.0 - File opening functionality
- webview_flutter ^4.13.1 - Embedded web view
- google_fonts ^6.3.3 - Google Fonts integration

**Development:**
- flutter_lints ^6.0.0 - Dart/Flutter linting rules

## Configuration

**Environment:**
- Configured via `pubspec.yaml` for dependencies
- No environment variables required (app is self-contained)
- Gradle config in `android/gradle.properties`

**Build:**
- Flutter build config in `pubspec.yaml`
- Android build config: `android/app/build.gradle.kts`
- Android manifest: `android/app/src/main/AndroidManifest.xml`
- Gradle properties: `android/gradle.properties`
  - JVM args: -Xmx8G heap allocation
  - AndroidX enabled

## Platform Requirements

**Development:**
- Flutter SDK 3.38.4+
- Dart SDK 3.10.8+
- Java 17 (for Android builds)
- Android SDK/API levels as configured in Flutter
- Xcode (for iOS builds, macOS only)

**Production:**
- Android: minSdk and targetSdk as configured in Flutter (APK release via GitHub Actions)
- iOS: iOS deployment target (standard Flutter iOS config)
- Windows: Standard Flutter Windows build
- macOS: Standard Flutter macOS build
- Linux: Standard Flutter Linux build
- Web: Standard Flutter Web build

---

*Stack analysis: 2026-02-11*
