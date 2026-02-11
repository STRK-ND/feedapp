# Coding Conventions

**Analysis Date:** 2026-02-11

## Naming Patterns

**Files:**
- Lowercase with underscores
- Examples: `update_service.dart`, `apk_downloader.dart`, `update_dialog.dart`
- Test files: `*_test.dart` suffix (e.g., `widget_test.dart`, `article_test.dart`)

**Directories:**
- Lowercase with underscores
- Examples: `services/`, `widgets/`

**Classes:**
- PascalCase
- Examples: `RssReaderApp`, `RssSource`, `Article`, `UpdateService`, `ApkDownloader`, `DownloadResult`

**Functions/Methods:**
- camelCase
- Private methods use underscore prefix: `_parseRssXml()`, `_formatReleaseDate()`, `_stripHtmlTags()`
- Static methods use camelCase: `fetchArticles()`, `checkForUpdates()`, `downloadApk()`

**Variables:**
- camelCase
- Private fields use underscore prefix: `_position`, `_rotation`, `_isAnimatingOut`

**Types/Parameters:**
- camelCase for parameters: `source`, `article`, `url`, `context`
- PascalCase for generic types: `List<Article>`, `Map<String, dynamic>`, `Future<UpdateInfo?>`

**Constants:**
- UPPER_SNAKE_CASE for constants: `COLOR_PRIMARY`, `MAX_RETRIES`
- Static constants use PascalCase for private: `_lastCheckedKey`, `_ignoredVersionKey`
- Color constants use PascalCase: `primary`, `accent`, `background`, `surface`

**Enums:**
- PascalCase for type, lowercase values
- Example: `enum ViewMode { cards, list }`

## Code Style

**Formatting:**
- Tool: Dart dartfmt (built-in to Flutter)
- Indentation: 2 spaces (Dart standard)

**Linting:**
- Tool: flutter_lints (configured in `analysis_options.yaml`)
- Uses `package:flutter_lints/flutter.yaml` recommended rules
- No custom rules enabled (all commented out in config)

**Quotes:**
- Single quotes preferred for strings: `'Curated Feeds'`, `'test-id'`
- Template strings use single quotes with `$` interpolation: `'$bytes B'`

**Imports:**
- Third-party imports first, then relative imports
- No explicit import statement grouping observed

## Import Organization

**Order:**
1. Dart SDK imports
2. Package imports
3. Relative/local imports

**Observed import pattern in `lib/main.dart`:**
```dart
// Dart SDK
import 'dart:async';
import 'dart:convert';

// Packages
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Local
import 'services/update_service.dart';
import 'widgets/update_dialog.dart';
```

**Path Aliases:**
- No path aliases configured (imports use relative paths)

## Error Handling

**Patterns:**
- Try-catch with debugPrint for logging errors
- Return null/empty defaults on error
- Silent error handling expected for UI components

**Observed pattern:**
```dart
try {
  final response = await http.get(Uri.parse(source.url)).timeout(
    const Duration(seconds: 8),
  );

  if (response.statusCode == 200) {
    return _parseRssXml(response.body, source);
  }
  debugPrint('HTTP ${response.statusCode} for ${source.name}');
  return [];
} catch (e) {
  debugPrint('Error fetching ${source.name}: $e');
  return [];
}
```

**HTTP errors:**
- Log status code on non-200 responses
- Return empty list instead of throwing

**Async errors:**
- Use timeout on async operations
- Log error details via debugPrint
- Provide fallback return values

## Logging

**Framework:** Flutter's debugPrint

**Patterns:**
- Use `debugPrint()` instead of `print()` to avoid flooding console
- Include context in log messages: `'Error fetching ${source.name}: $e'`
- Log to debug output only (no external logging service)

**Observed logging locations:**
- HTTP failures in `RssFeedService.fetchArticles()` (line 307, 310)
- XML parsing errors in `RssFeedService._parseRssXml()` (line 474)
- Update check errors in `UpdateService.checkForUpdates()` (line 67)
- Download errors in `ApkDownloader.downloadApk()` (line 60)
- Cleanup operations in `ApkDownloader.cleanupOldDownloads()` (line 83, 87)

## Comments

**When to Comment:**
- Inline comments for clarification in parsing logic
- Debug log explanations in catch blocks
- No formal documentation comments (Javadoc-style not observed)

**Observed comment examples:**
```dart
// GitHub repository URL for auto-updates
static const String githubApiUrl =
    'https://api.github.com/repos/STRK-ND/feedapp/releases/latest';

// Keys for SharedPreferences
static const String _lastCheckedKey = 'last_update_check';
static const String _ignoredVersionKey = 'ignored_update_version';

// Remove 'v' prefix if present
```

**JSDoc/TSDoc:**
- No JSDoc or DartDoc patterns observed in codebase

## Function Design

**Size:**
- No explicit size guidelines observed
- `lib/main.dart` is 2935 lines (large file with multiple classes)
- Service files range 98-198 lines (reasonable size)

**Parameters:**
- Required positional parameters first
- Optional named parameters in widgets and callbacks
- Callback callbacks typed as VoidCallback or specific signatures
- Example: `Future<DownloadResult> downloadApk(String url, {required ProgressCallback onProgress})`

**Return Values:**
- Use nullable return types for potential failure: `Future<UpdateInfo?>`
- Return empty collections on failure: `return []` instead of throwing
- Use result wrapper types for complex returns: `DownloadResult`

**Async patterns:**
- Mark async methods with `Future<T>` return type
- Use `await` for async operations
- Use `.timeout()` for network operations

## Module Design

**Exports:**
- No barrel files observed
- Each file exports its classes directly
- Imports reference specific files

**Model pattern:**
```dart
class Article {
  final String id;
  final String title;
  bool isRead;
  bool isSaved;

  Article({
    required this.id,
    required this.title,
    this.isRead = false,
    this.isSaved = false,
  });

  Map<String, dynamic> toJson() { /* ... */ }
  factory Article.fromJson(Map<String, dynamic> json) { /* ... */ }
}
```

**Service pattern:**
- Static class with static methods
- Private helper methods prefixed with underscore
- Private constants for config values

**Widget pattern:**
- Stateless widgets for simple components
- Stateful widgets for interactive components
- Private state classes prefixed with underscore: `_MyWidgetState`
- Use `super.key` in const constructors

---

*Convention analysis: 2026-02-11*
