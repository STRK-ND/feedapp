# APK Versioning Design

## Overview
Configure Android builds to output APK files with application name and version in the filename.

## Current State
- **App name:** `curatedfeeds`
- **Version:** `1.0.0` (from `pubspec.yaml`)
- **Current APK output:** `app-release.apk` (generic name, no version info)

## Design Decision
**Option B: Android Gradle configuration** — Configure in `build.gradle.kts` to rename APK automatically for every build (CI + local).

## Changes Required

### File: `android/app/build.gradle.kts`

Add `archiveBaseName` to the release build type:

```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
        // Rename APK: curatedfeeds-{versionName}-{versionCode}.apk
        archiveBaseName.set("curatedfeeds-${flutter.versionName}-${flutter.versionCode}")
    }
}
```

## Expected Output
- **Before:** `build/app/outputs/flutter-apk/app-release.apk`
- **After:** `build/app/outputs/flutter-apk/curatedfeeds-1.0.0-1.apk`

## Why This Approach
- Works for both CI and local builds automatically
- No extra steps or scripts needed
- Keeps versioning logic where Android versioning already lives
- Format: `{appName}-{versionName}-{versionCode}`

## No Changes Needed
- `pubspec.yaml` — version already set
- `.github/workflows/build.yml` — already extracts version from tags for release title

## Verification
After implementation, run `flutter build apk --release` and verify:
1. APK filename includes version: `curatedfeeds-1.0.0-1.apk`
2. GitHub release shows version in title (existing behavior)