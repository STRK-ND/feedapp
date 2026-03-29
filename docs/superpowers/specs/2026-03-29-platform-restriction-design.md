# Platform Restriction Design

**Date:** 2026-03-29
**Goal:** Restrict app to iOS and Android only

---

## Overview

Restrict the Curated Feeds Flutter app to run only on iOS and Android platforms, removing support for web, Windows, macOS, and Linux. Add iOS platform support since it's currently missing.

---

## Design

### 1. Add iOS Platform

Run the following command to add iOS platform support:

```bash
flutter create --platforms=ios .
```

This creates:
- `ios/` folder with Xcode project
- `ios/Runner.xcodeproj/`
- `ios/Runner/Info.plist`
- iOS-specific configuration files

### 2. Restrict pubspec.yaml

Add explicit platform declaration to prevent building for other platforms:

```yaml
flutter:
  uses-material-design: true
  platforms:
    - ios
    - android
```

This Flutter 3.x+ feature:
- Prevents `flutter build web/windows/mac/linux` from working
- Shows warnings if a package requires unsupported platforms
- Makes platform intent explicit in code

---

## Implementation

1. Run `flutter create --platforms=ios .` to add iOS platform
2. Update `pubspec.yaml` with explicit platform restrictions

---

## Verification

- Confirm `ios/` folder exists with valid Xcode project
- Confirm `flutter build ios` works without errors
- Confirm `flutter build web` fails with platform restriction error