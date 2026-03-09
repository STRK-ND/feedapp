## Context

Current build output:
- Release APK: `build/app/outputs/flutter-apk/app-release.apk`
- Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`

Expected output after fix:
- Release APK: `build/app/outputs/flutter-apk/curatedfeeds-1.0.0.apk`
- Debug APK: `build/app/outputs/flutter-apk/curatedfeeds-1.0.0-debug.apk`

## Goals / Non-Goals

**Goals:**
- Configure build to include app name and version in APK filename

**Non-Goals:**
- Changing app label in launcher

## Decisions

1. **Build config approach**: Use Gradle's `project.ext` to read version from Flutter and apply to output filename
2. **Filename format**: `{appName}-{version}.apk` for release, `{appName}-{version}-debug.apk` for debug

## Risks / Trade-offs

- Low risk - only changes build output filename
- Need to ensure version is correctly read from Flutter's build configuration