# Testing Patterns

**Analysis Date:** 2026-02-11

## Test Framework

**Runner:**
- flutter_test (Flutter's built-in testing framework)
- Flutter version: 3.38.9 (from workflow config)
- Config: Default Flutter test configuration

**Assertion Library:**
- Built-in Flutter test assertions (`expect`, `find`, `tester` mechanisms)

**Run Commands:**
```bash
flutter test                             # Run all tests
flutter test --watch                     # Watch mode (not explicitly observed)
flutter test --coverage                  # Coverage (not explicitly observed)
```

## Test File Organization

**Location:**
- Test files in `test/` directory (separate from source)
- Source files in `lib/` directory

**Naming:**
- Pattern: `*_test.dart` or `*_test.dart` suffix
- Examples:
  - `test/widget_test.dart` - Widget tests
  - `test/article_test.dart` - Model tests

**Structure:**
```
test/
├── widget_test.dart      # UI widget integration tests
└── article_test.dart     # Unit tests for Article model
```

## Test Structure

**Suite Organization:**
```dart
// Widget test pattern from test/widget_test.dart
void main() {
  testWidgets('App starts with RssFeedScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const RssReaderApp());
    await tester.pumpAndSettle();

    expect(find.text('Curated Feeds'), findsOneWidget);
    expect(find.byIcon(Icons.rss_feed_rounded), findsOneWidget);
  });

  testWidgets('App theme has expected colors', (WidgetTester tester) async {
    await tester.pumpWidget(const RssReaderApp());
    await tester.pumpAndSettle();

    final Container container = tester.widget(find.byType(Container).first);
    expect(decoration.gradient, isNotNull);
  });
}
```

**Unit test pattern from test/article_test.dart:**
```dart
void main() {
  group('Article model', () {
    test('should create Article with all fields', () {
      // Arrange & Act
      final article = Article(
        id: 'test-id',
        title: 'Test Article',
        description: 'Test description',
        fullContent: 'Full content',
        link: 'https://example.com/article',
        sourceId: 'test-source',
        sourceName: 'Test Source',
        pubDate: DateTime(2024, 1, 15),
        author: 'Test Author',
        imageUrl: 'https://example.com/image.jpg',
        isRead: false,
        isSaved: false,
      );

      // Assert
      expect(article.id, 'test-id');
      expect(article.title, 'Test Article');
    });
  });
}
```

**Patterns:**
- Setup pattern: Build widget or instantiate model in test body
- Teardown pattern: None observed (tests are isolated)
- Assertion pattern: `expect(actual, matcher)` using Flutter matchers

## Mocking

**Framework:**
- No mocking framework detected (mockito, mocktail not in pubspec.yaml)
- Tests use direct model instantiation

**Patterns:**
```dart
// Direct instantiation pattern (no mocking)
final article = Article(
  id: 'test-id',
  title: 'Test Article',
  // ... required fields
);

// Article model duplicated in test file when source is not imported
class Article {
  final String id;
  final String title;
  // ... fields
  Article({
    required this.id,
    required this.title,
    // ...
  });
}
```

**What to Mock:**
- Not observed in current codebase

**What NOT to Mock:**
- Simple data models (Article) - instantiate directly
- DateTime - create instances directly

## Fixtures and Factories

**Test Data:**
```dart
// Pattern from test/article_test.dart - inline test data
final article = Article(
  id: 'test-id',
  title: 'Test Article',
  description: 'Test description',
  fullContent: 'Full content',
  link: 'https://example.com/article',
  sourceId: 'test-source',
  sourceName: 'Test Source',
  pubDate: DateTime(2024, 1, 15),
  author: 'Test Author',
  imageUrl: 'https://example.com/image.jpg',
);

// List based test data
final articles = [
  Article(id: '1', title: 'Oldest', ...),
  Article(id: '2', title: 'Newest', ...),
  Article(id: '3', title: 'Middle', ...),
];
```

**Location:**
- Test data defined inline within test functions
- No separate fixtures directory observed
- No factory/helper functions for test data generation

**Observed test groups in article_test.dart:**
- `Article model` - Model creation, serialization, deserialization
- `Date formatting calculations` - DateTime difference calculations
- `Time formatting edge cases` - Boundary conditions for dates
- `Article sorting` - Sorting by date
- `Article filtering by read status` - Filtering logic
- `Article filtering by saved status` - Filtering logic
- `Search functionality` - Search matching (title, description, source)

## Coverage

**Requirements:**
- No enforced coverage target observed

**View Coverage:**
```bash
flutter test --coverage
# Coverage report not currently configured
```

**Current test coverage:**
- Widget tests: Basic app startup and theme verification
- Model tests: Comprehensive Article model testing
- Service tests: None observed (UpdateService, ApkDownloader untested)
- Widget integration: Limited (only app-level smoke tests)

## Test Types

**Unit Tests:**
- Scope: Model classes, pure functions, data transformations
- Approach: Direct instantiation, no mocking framework
- Example: `Article` model testing in `test/article_test.dart`
- Focus: JSON serialization/deserialization, filtering, sorting, search

**Integration Tests:**
- Scope: Widget rendering, UI interactions
- Approach: `testWidgets()` with WidgetTester
- Example: App startup and theme verification in `test/widget_test.dart`
- Focus: Widget tree structure, presence of expected elements

**E2E Tests:**
- Framework: Not used
- No integration or end-to-end tests beyond widget tests

## Common Patterns

**Arrange-Act-Assert:**
```dart
// Arrange & Act together for simple tests
final article = Article(
  id: 'test-id',
  title: 'Test Article',
  // ... other fields
);

// Assert
expect(article.id, 'test-id');
```

```dart
// Separate Arrange, Act, Assert pattern
// Arrange
final json = {
  'id': 'test-id',
  'title': 'Test Article',
  // ... other fields
};

// Act
final article = Article.fromJson(json);

// Assert
expect(article.id, 'test-id');
expect(article.title, 'Test Article');
```

**Async Testing:**
```dart
// Widget test async pattern
testWidgets('App starts with RssFeedScreen', (WidgetTester tester) async {
  await tester.pumpWidget(const RssReaderApp());
  await tester.pumpAndSettle();

  // Verify async operations completed
  expect(find.text('Curated Feeds'), findsOneWidget);
});
```

**Error Testing:**
```dart
// Testing optional field defaults
test('should handle missing optional fields in JSON', () {
  final json = {
    'id': 'test-id',
    'title': 'Test Article',
    // ... required fields only
  };

  final article = Article.fromJson(json);

  expect(article.author, null);
  expect(article.imageUrl, null);
  expect(article.isRead, false);  // Defaults to false
  expect(article.isSaved, false); // Defaults to false
});
```

**Grouping tests:**
```dart
void main() {
  group('Article model', () {
    test('...', () { });
    test('...', () { });
  });

  group('Date formatting calculations', () {
    test('...', () { });
    test('...', () { });
  });

  group('Search functionality', () {
    test('should match title in search', () { });
    test('should match description in search', () { });
    test('should be case insensitive', () { });
  });
}
```

**Date testing:**
```dart
test('should calculate correct difference in minutes', () {
  final now = DateTime.now();
  final articleDate = now.subtract(const Duration(minutes: 30));

  final difference = now.difference(articleDate);

  expect(difference.inMinutes, 30);
  expect(difference.inHours, 0);
});
```

---

*Testing analysis: 2026-02-11*
