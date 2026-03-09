# APK Versioning Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Configure Android builds to output APK files with application name and version in the filename.

**Architecture:** Modify Android Gradle configuration to set `archiveBaseName` in build.gradle.kts.

**Tech Stack:** Gradle (Kotlin DSL), Flutter Android build

---

### Task 1: Add archiveBaseName to release build type

**File:** `android/app/build.gradle.kts`

**Step 1: Read current build.gradle.kts to find buildTypes block**
```bash
Read: android/app/build.gradle.kts
Find: buildTypes { ... }
```

**Step 2: Add archiveBaseName to release build type**
Add inside the `release` block (after proguardFiles):

```kotlin
// Rename APK: curatedfeeds-{versionName}-{versionCode}.apk
archiveBaseName.set("curatedfeeds-${flutter.versionName}-${flutter.versionCode}")
```

**Step 3: Build and verify**
```bash
flutter build apk --release
```

Expected output: `build/app/outputs/flutter-apk/curatedfeeds-1.0.0-1.apk`

**Step 4: Commit**
```bash
git add android/app/build.gradle.kts
git commit -m "feat: add version to APK filename

- Add archiveBaseName to release build type
- Output: curatedfeeds-{version}-{buildCode}.apk

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

## Verification Checklist
- [ ] APK filename includes version: `curatedfeeds-1.0.0-1.apk`
- [ ] APK is valid and can be installed