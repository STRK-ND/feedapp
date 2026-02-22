# Coding Conventions

**Analysis Date:** 2025-02-22

## Naming Patterns

**Files:**
- Use lowercase with underscores (snake_case)
  - Example: `article_repository.dart`, `feed_screen.dart`, `utils.dart`

**Classes and Types:**
- Use PascalCase
  - Example: `Article`, `ArticleRepository`, `FeedProviderRegistry`

**Functions and Methods:**
- Use camelCase
  - Example: `fetchArticles()`, `parseXml()`, `markAsRead()`

**Variables and Fields:**
- Use camelCase
  - Example: `articles`, `isLoading`, `_cachedArticles`

**Private Members:**
- Prefix with underscore (_)
  - Example: `_storageService`, `_cachedArticles`, `_onSwipeRight()`

**Constants:**
- Use uppercase with underscores (SCREAMING_SNAKE_CASE) in constants.dart
  - Example: `AppConfig.maxCachedArticles`, `AppColors.primary`

## Code Style

**Formatting:**
- Uses `flutter_lints: ^6.0.0` for linting rules
- Analysis options enforced via `analysis_options.yaml`
- Line length: Not explicitly configured (follows Flutter defaults)

**Key Lint Rules:**
- `prefer_const_constructors: true` - Use const constructors when possible
- `prefer_const_declarations: true` - Use const for immutable fields
- `prefer_final_fields: true` - Use final for fields that don't change
- `prefer_final_locals: true` - Use final for local variables that don't change
- `prefer_single_quotes: true` - Use single quotes for strings
- `prefer_relative_imports: true` - Use relative imports within lib/
- `unawaited_futures: true` - Warn on unhandled futures
- `use_key_in_widget_constructors: true` - Always use key parameter

**Example:**
```dart
class Article {
  final String id;  // Final field
  final String title;
  bool isRead;       // Mutable field

  Article({
    required this.id,
    required this.title,
    this.isRead = false,  // Default value
  });
}
```

## Import Organization

**Order:**
1. Dart SDK imports (`dart:async`, `dart:convert`)
2. Flutter SDK imports (`package:flutter/material.dart`)
3. External package imports (`package:xml/xml.dart`, `package:get_it/get_it.dart`)
4. Relative imports (`../models/article.dart`, `./utils/constants.dart`)

**Path Aliases:**
- Uses relative imports, not package aliases
- Relative path format: `../services/storage_service.dart`

## Error Handling

**Patterns:**
- Custom `Result<T>` class with `data` and `error` fields
- Use `Result.success()` for successful operations
- Use `Result.failure()` for failed operations
- Check with `isSuccess` or `isFailure` properties
- Get data with `dataOrThrow` (throws on failure)

**Example:**
```dart
class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result.success(this.data) : error = null, isSuccess = true;
  Result.failure(this.error) : data = null, isSuccess = false;

  T get dataOrThrow => isSuccess ? data! : throw Exception(error);
}

// Usage:
Future<Result<List<Article>>> fetchAllArticles() async {
  try {
    final articles = await _storageService.loadArticles();
    return Result.success(articles);
  } catch (e) {
    ErrorHandler.logError('Failed to fetch articles', error: e);
    return Result.failure(ErrorHandler.getUserMessage(e));
  }
}
```

**Error Severity:** Use `ErrorSeverity` enum for log levels:
- `ErrorSeverity.low` - Info messages
- `ErrorSeverity.medium` - Warnings
- `ErrorSeverity.high` - Errors
- `ErrorSeverity.critical` - Critical errors

## Logging

**Framework:** `ErrorHandler` utility class with static methods

**Patterns:**
```dart
// Log with severity:
ErrorHandler.logError('Message', severity: ErrorSeverity.low);

// Shortcut extensions:
ErrorHandlerExtensions.logInfo('Info message');     // Low severity
ErrorHandlerExtensions.logWarning('Warning');       // Medium severity

// User-facing errors:
ErrorHandler.getUserMessage(error); // Gets friendly message

// Error checks:
ErrorHandler.shouldShowToUser(error); // Show to user?
ErrorHandler.isRecoverable(error);    // Can retry?
```

## Comments

**When to Comment:**
- Document classes at top with purpose
- Explain complex algorithms or parsing logic
- TODO comments for future improvements
- FIXME comments for known issues

**Example:**
```dart
/// Repository for managing article data access
/// This repository bridges between the UI layer and the services layer,
/// providing a clean abstraction for article operations.
class ArticleRepository {
  // ...
}
```

**TODO/FIXME Usage:**
- Use TODO: for planned improvements
- Use FIXME: for bugs that need fixing
- Include brief description of what needs to be done

## Function Design

**Size:** Keep functions focused on single responsibility

**Parameters:**
- Use named parameters for optional values
- Use required for mandatory named parameters
- Keep parameter lists reasonable (aim for < 5)

**Return Values:**
- Return Result<T> instead of throwing exceptions for recoverable errors
- Return nullable types when null is a valid return value
- Document what null return means in function comments

**Async Functions:**
- Always mark async functions as Future<T>
- Handle cancellations appropriately
- Use timeout for network operations

**Example:**
```dart
Future<Result<void>> markAsRead(Article article) async {
  try {
    // Implementation
    return Result.success(null);
  } catch (e) {
    return Result.failure(ErrorHandler.getUserMessage(e));
  }
}
```

## Module Design

**Exports:**
- Each file typically exports one main class
- Private helper classes can be in same file
- Extension methods grouped with classes they extend

**Dependencies:**
- Use constructor dependency injection (not Service Locator patterns)
- Accept null-safe parameters with ?? fallback
- Document dependencies in class comments

**Singleton Pattern:**
- Use in services that should have single instance
- Private constructor + factory constructor pattern

**Example:**
```dart
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
}
```

## Widget Design

**Stateless vs Stateful:**
- Use StatelessWidget for pure presentation
- Use StatefulWidget for mutable state
- Use keys for stateful widgets that get rebuilt

**Widget Keys:**
- Always include key parameter in constructors
- Use const constructors when possible

**Const Constructors:**
- Mark widgets and constructors as const when possible
- Allows compile-time optimization

**Example:**
```dart
class MyWidget extends StatelessWidget {
  const MyWidget({super.key});  // const constructor

  @override
  Widget build(BuildContext context) {
    return const Text('Hello');  // const widget
  }
}
```

---
*Convention analysis: 2025-02-22*
