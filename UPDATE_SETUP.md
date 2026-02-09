# Auto-Update Setup Guide

This guide explains how to set up and use the built-in auto-update feature for Curated Feeds.

## Configuration

### 1. Update Repository Information

Edit [lib/services/update_service.dart](lib/services/update_service.dart) line 4:

```dart
static const String githubApiUrl =
    'https://api.github.com/repos/YOUR_USERNAME/YOUR_REPO/releases/latest';
```

Replace `YOUR_USERNAME` and `YOUR_REPO` with your actual GitHub username and repository name.

Example:
```dart
static const String githubApiUrl =
    'https://api.github.com/repos/rajat/curated-feeds/releases/latest';
```

### 2. GitHub Actions Workflow

The [`.github/workflows/build.yml`](.github/workflows/build.yml) workflow is automatically triggered when you push a version tag:

```bash
git tag v1.1.0
git push origin v1.1.0
```

This will:
1. Build the Android APK
2. Extract version information from the tag
3. Generate release notes from [CHANGELOG.md](CHANGELOG.md)
4. Create a GitHub Release with the APK attached

## How to Create a Release

1. Update the version in [pubspec.yaml](pubspec.yaml):
   ```yaml
   version: 1.1.0+2
   ```
   Format: `VERSION_NAME+BUILD_NUMBER`

2. Update [CHANGELOG.md](CHANGELOG.md) with release notes:
   ```markdown
   ## [1.1.0] - 2025-02-10

   ### Added
   - New feature description

   ### Fixed
   - Bug fix description
   ```

3. Commit and tag:
   ```bash
   git add .
   git commit -m "Release v1.1.0"
   git tag v1.1.0
   git push origin master
   git push origin v1.1.0
   ```

4. GitHub Actions will automatically build and publish the release

## How Updates Work

### On App Launch
- The app checks GitHub API for the latest release (throttled to once per hour)
- If a newer version is found, an update dialog is shown
- Users can update now, skip this version, or ignore

### Manual Check
- Tap the menu icon (⋮) in the top-right corner
- Select "Check for updates"

### Update Dialog
- Shows version number and release date
- Displays release notes from CHANGELOG
- "Update Now" button downloads the APK
- "Skip this version" option to dismiss notification

## Features

- **Rate Limiting**: Checks only once per hour unless forced
- **Ignore Specific Versions**: Users can skip specific update versions
- **Changelog Integration**: Automatically extracts release notes
- **Error Handling**: Graceful failure if GitHub API is unavailable
- **Background Check**: Silent check on app startup

## Troubleshooting

### Updates Not Showing
- Verify `githubApiUrl` is correct in [update_service.dart](lib/services/update_service.dart)
- Check that GitHub repository is public (or set up authentication for private repos)
- Ensure release assets include `.apk` file

### Build Fails
- Check GitHub Actions logs at `https://github.com/YOUR_USERNAME/YOUR_REPO/actions`
- Ensure Flutter SDK version in workflow is compatible with your code
- Verify signing configuration if using release builds

### Version Comparison Issues
- Make sure version tags follow semantic versioning: `v1.2.3`
- Keep `pubspec.yaml` version in sync with git tags

## Advanced: Private Repository

For private repositories, you'll need to:

1. Create a fine-grained personal access token with `repo` scope
2. Add it as a GitHub Actions secret: `GITHUB_TOKEN`
3. Update [update_service.dart](lib/services/update_service.dart) to include authentication:
   ```dart
   final response = await http.get(
     Uri.parse(githubApiUrl),
     headers: {
       'Accept': 'application/vnd.github.v3+json',
       'Authorization': 'Bearer YOUR_TOKEN', // Not secure for client apps!
     },
   );
   ```

**Note**: For production apps, use a backend proxy to avoid exposing credentials in the client app.
