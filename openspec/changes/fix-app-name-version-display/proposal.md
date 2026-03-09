## Why

The release APK should have a versioned filename for easy identification. Currently it generates as "app-release.apk" which doesn't indicate the version.

## What Changes

- Configure Android build to generate APK with version in filename
- Release APK will be: `curatedfeeds-1.0.0.apk` instead of `app-release.apk`
- Debug APK will be: `curatedfeeds-1.0.0-debug.apk`

## Capabilities

### New Capabilities
- `versioned-apk-filename`: Generate APK with version in filename

### Modified Capabilities
None

## Impact

- android/app/build.gradle.kts: Update to include version in output filename