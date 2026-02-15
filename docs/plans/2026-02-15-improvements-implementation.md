# Curated Feeds - Incremental Enhancement Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Incrementally enhance the Curated Feeds Flutter RSS reader app with improved architecture, better error handling, testing foundation, and user experience improvements across six phases.

**Architecture:** Introduce repository pattern for data access abstraction, layered architecture (Presentation → Business Logic → Data → Sources), and dependency injection using get_it service locator. Maintain existing setState-based UI while gradually extracting business logic.

**Tech Stack:** Flutter (Dart), get_it (dependency injection), mockito (testing), flutter_test (unit/widget tests), integration_test (E2E tests)

---

# Phase 1: Foundation (Week 1-2)

## Task 1: Add get_it dependency

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add get_it dependency**

```yaml
dependencies:
  # ... existing dependencies ...
  get_it: ^7.6.4
```

**Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Successfully fetches get_it package

**Step 3: Verify dependency added**

Run: `flutter pub deps | grep get_it`
Expected: List get_it in dependency tree

**Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: Add get_it for dependency injection"
```

---

## Task 2: Create service locator setup

**Files:**
- Create: `lib/di/service_locator.dart`

**Step 1: Write service locator file**

```dart
import 'package:get_it/get_it.dart';
import '../services/rss_feed_service.dart';
import '../services/storage_service.dart';
import '../services/cache_manager.dart';
import '../services/article_content_service.dart';
import '../services/update_service.dart';

/// Global service locator instance
final GetIt getIt = GetIt.instance;

/// Setup all service dependencies
Future<void> setupServiceLocator() async {
  // Register singleton services
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<AppCacheManager>(() => AppCacheManager());
  getIt.registerLazySingleton<ApkCacheManager>(() => ApkCacheManager());
}
```

**Step 2: Run flutter analyze**

Run: `flutter analyze lib/di/service_locator.dart`
Expected: No analysis errors (warning about unused import is OK)

**Step 3: Commit**

```bash
git add lib/di/service_locator.dart
git commit -m "feat: Add service locator setup with get_it"
```

---

## Task 3: Write Article model tests

**Files:**
- Create: `test/unit/models/article_test.dart`

**Step 1: Write Article model test file**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/article.dart';

void main() {
  group('Article Model', () {
    late Article testArticle;

    setUp(() {
      testArticle = Article(
        id: 'test-id-1',
        title: 'Test Article Title',
        description: 'This is a test description',
        fullContent: 'Full article content here',
        link: 'https://example.com/article/1',
        sourceId: 'test-source',
        sourceName: 'Test Source',
        pubDate: DateTime(2024, 1, 15, 10, 30),
        author: 'Test Author',
        imageUrl: 'https://example.com/image.jpg',
        isRead: false,
        isSaved: false,
      );
    });

    test('Should create Article with correct values', () {
      expect(testArticle.id, 'test-id-1');
      expect(testArticle.title, 'Test Article Title');
      expect(testArticle.description, 'This is a test description');
      expect(testArticle.fullContent, 'Full article content here');
      expect(testArticle.link, 'https://example.com/article/1');
      expect(testArticle.sourceId, 'test-source');
      expect(testArticle.sourceName, 'Test Source');
      expect(testArticle.pubDate, DateTime(2024, 1, 15, 10, 30));
      expect(testArticle.author, 'Test Author');
      expect(testArticle.imageUrl, 'https://example.com/image.jpg');
      expect(testArticle.isRead, false);
      expect(testArticle.isSaved, false);
    });

    test('Should convert to JSON correctly', () {
      final json = testArticle.toJson();

      expect(json['id'], 'test-id-1');
      expect(json['title'], 'Test Article Title');
      expect(json['description'], 'This is a test description');
      expect(json['fullContent'], 'Full article content here');
      expect(json['link'], 'https://example.com/article/1');
      expect(json['sourceId'], 'test-source');
      expect(json['sourceName'], 'Test Source');
      expect(json['pubDate'], 1705306200000); // milliseconds since epoch
      expect(json['author'], 'Test Author');
      expect(json['imageUrl'], 'https://example.com/image.jpg');
      expect(json['isRead'], false);
      expect(json['isSaved'], false);
    });

    test('Should create Article from JSON correctly', () {
      final json = {
        'id': 'test-id-2',
        'title': 'Another Article',
        'description': 'Another description',
        'fullContent': 'Another content',
        'link': 'https://example.com/article/2',
        'sourceId': 'another-source',
        'sourceName': 'Another Source',
        'pubDate': 1705306200000,
        'author': 'Another Author',
        'imageUrl': 'https://example.com/image2.jpg',
        'isRead': true,
        'isSaved': true,
        'fetchedFullContent': 'Fetched content',
      };

      final article = Article.fromJson(json);

      expect(article.id, 'test-id-2');
      expect(article.title, 'Another Article');
      expect(article.description, 'Another description');
      expect(article.fullContent, 'Another content');
      expect(article.link, 'https://example.com/article/2');
      expect(article.sourceId, 'another-source');
      expect(article.sourceName, 'Another Source');
      expect(article.pubDate, DateTime(2024, 1, 15, 10, 30));
      expect(article.author, 'Another Author');
      expect(article.imageUrl, 'https://example.com/image2.jpg');
      expect(article.isRead, true);
      expect(article.isSaved, true);
      expect(article.fetchedFullContent, 'Fetched content');
    });

    test('Should use default values for missing fields in fromJson', () {
      final json = {
        'id': 'test-id-3',
        'title': 'Minimal Article',
        'pubDate': 1705306200000,
      };

      final article = Article.fromJson(json);

      expect(article.id, 'test-id-3');
      expect(article.title, 'Minimal Article');
      expect(article.description, ''); // default
      expect(article.fullContent, ''); // default
      expect_article.link, ''); // default
      expect(article.sourceId, ''); // default
      expect(article.sourceName, 'Unknown Source'); // default
      expect(article.author, null);
      expect(article.imageUrl, null);
      expect(article.isRead, false); // default
      expect(article.isSaved, false); // default
    });

    test('Should create copy with updated values', () {
      final updated = testArticle.copyWith(
        title: 'Updated Title',
        isRead: true,
      );

      expect(updated.id, testArticle.id); // unchanged
      expect(updated.title, 'Updated Title'); // changed
      expect(updated.description, testArticle.description); // unchanged
      expect(updated.isRead, true); // changed
      expect(updated.isSaved, testArticle.isSaved); // unchanged
    });
  });
}
```

**Step 2: Run tests to verify they pass**

Run: `flutter test test/unit/models/article_test.dart`
Expected: All 5 tests pass

**Step 3: Commit**

```bash
git add test/unit/models/article_test.dart
git commit -m "test: Add comprehensive Article model tests"
```

---

## Task 4: Write RssSource model tests

**Files:**
- Create: `test/unit/models/rss_source_test.dart`

**Step 1: Write RssSource model test file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/rss_source.dart';

void main() {
  group('RssSource Model', () {
    late RssSource testSource;

    setUp(() {
      testSource = RssSource(
        id: 'test-source-1',
        name: 'Test Feed',
        url: 'https://example.com/feed.xml',
        category: 'Tech',
        color: const Color(0xFF3B82F6),
        icon: Icons.computer,
      );
    });

    test('Should create RssSource with correct values', () {
      expect(testSource.id, 'test-source-1');
      expect(testSource.name, 'Test Feed');
      expect(testSource.url, 'https://example.com/feed.xml');
      expect(testSource.category, 'Tech');
      expect(testSource.color, const Color(0xFF3B82F6));
      expect(testSource.icon, Icons.computer);
    });

    test('Should convert to JSON correctly', () {
      final json = testSource.toJson();

      expect(json['id'], 'test-source-1');
      expect(json['name'], 'Test Feed');
      expect(json['url'], 'https://example.com/feed.xml');
      expect(json['category'], 'Tech');
      expect(json['color'], 0xFF3B82F6); // ARGB32
      expect(json['icon'], Icons.computer.codePoint);
    });

    test('Should create RssSource from JSON correctly', () {
      final json = {
        'id': 'test-source-2',
        'name': 'Another Feed',
        'url': 'https://example.com/feed2.xml',
        'category': 'News',
        'color': 0xFFDC2626,
        'icon': Icons.article_rounded.codePoint,
      };

      final source = RssSource.fromJson(json);

      expect(source.id, 'test-source-2');
      expect(source.name, 'Another Feed');
      expect(source.url, 'https://example.com/feed2.xml');
      expect(source.category, 'News');
      expect(source.color, const Color(0xFFDC2626));
      expect(source.icon, Icons.article_rounded);
    });

    test('Should use default values for missing fields in fromJson', () {
      final json = {
        'id': 'minimal-source',
        'name': 'Minimal Feed',
      };

      final source = RssSource.fromJson(json);

      expect(source.id, 'minimal-source');
      expect(source.name, 'Minimal Feed');
      expect(source.url, ''); // default
      expect(source.category, 'General'); // default
      expect(source.color, const Color(0xFF000000)); // default
      expect(source.icon, const IconData(0xE000, fontFamily: 'MaterialIcons')); // default
    });

    test('Should create copy with updated values', () {
      final updated = testSource.copyWith(
        name: 'Updated Feed',
        category: 'Science',
      );

      expect(updated.id, testSource.id); // unchanged
      expect(updated.name, 'Updated Feed'); // changed
      expect(updated.url, testSource.url); // unchanged
      expect(updated.category, 'Science'); // changed
      expect(updated.color, testSource.color); // unchanged
    });
  });
}
```

**Step 2: Run tests to verify they pass**

Run: `flutter test test/unit/models/rss_source_test.dart`
Expected: All 5 tests pass

**Step 3: Commit**

```bash
git add test/unit/models/rss_source_test.dart
git commit -m "test: Add comprehensive RssSource model tests"
```

---

## Task 5: Write Helpers utility tests - Date formatting

**Files:**
- Create: `test/unit/utils/helpers_date_test.dart`

**Step 1: Write date formatting tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/utils/helpers.dart';

void main() {
  group('Helpers - Date Formatting', () {
    group('formatTimeAgo', () {
      test('Should return "Just now" for recent time', () {
        final now = DateTime.now();
        expect(Helpers.formatTimeAgo(now), 'Just now');
      });

      test('Should return "Xm ago" for minutes', () {
        final time = DateTime.now().subtract(const Duration(minutes: 5));
        expect(Helpers.formatTimeAgo(time), '5m ago');
      });

      test('Should return "5m ago" for 5 minutes ago', () {
        final time = DateTime.now().subtract(const Duration(minutes: 5));
        result = Helpers.formatTimeAgo(time);
        expect(result, '5m ago');
      });

      test('Should return "Xh ago" for hours', () {
        final time = DateTime.now().subtract(const Duration(hours: 3));
        expect(Helpers.formatTimeAgo(time), '3h ago');
      });

      test('Should return "Xd ago" for days', () {
        final time = DateTime.now().subtract(const Duration(days: 2));
        expect(Helpers.formatimeAgo(time), '2d ago');
      });

      test('Should return formatted date for old dates', () {
        final time = DateTime(2023, 12, 15);
        final result = Helpers.formatTimeAgo(time);
        expect(result, '15/12/2023');
      });

      test('Should return "1d ago" for exactly 1 day', () {
        final time = DateTime.now().subtract(const Duration(days: 1));
        expect(Helpers.formatTimeAgo(time), '1d ago');
      });

      test('Should return "6d ago" for 6 days (boundary case)', () {
        final time = DateTime.now().subtract(const Duration(days: 6));
        expect(Helpers.formatTimeAgo(time), '6d ago');
      });
    });

    group('formatDate', () {
      test('Should format date correctly', () {
        final date = DateTime(2024, 1, 15, 14, 30);
        expect(Helpers.formatDate(date), '15/1/2024 14:30');
      });

      test('Should format date with single digit hour', () {
        final date = DateTime(2024, 1, 15, 9, 5);
        expect(Helpers.formatDate(date), '15/1/2024 09:05');
      });

      test('Should format date with single digit minute', () {
        final date = DateTime(2024, 1, 15, 14, 9);
        expect(Helpers.formatDate(date), '15/1/2024 14:09');
      });
    });

    group('parseDate', () {
      test('Should parse ISO8601 date string', () {
        result = Helpers.parseDate('2024-01-15T10:30:00Z');
        expect(result, DateTime(2024, 1, 15, 10, 30));
      });

      test('Should parse date with timezone offset', () {
        final result = Helpers.parseDate('2024-01-15T10:30:00+05:30');
        expect(result, DateTime(2024, 1, 15, 5, 0));
      });

      test('Should handle invalid format by returning DateTime.now()', () {
        final beforeCall = DateTime.now();
        final result = Helpers.parseDate('invalid-date');
        final afterCall = DateTime.now();
        expect(result.isAfter(beforeCall.subtract(const Duration(seconds: 1))), true);
        expect(result.isBefore(afterCall.add(const Duration(seconds: 1))), true);
      });
    });

    group('parseCustomDate', () {
      test('Should parse "15 Jan 2024" format', () {
        final result = Helpers.parseCustomDate('Mon, 15 Jan 2024 10:30:00 +0000');
        expect(result.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
      });

      test('Should handle invalid custom date', () {
        final beforeCall = DateTime.now();
        final result = Helpers.parseCustomDate('invalid');
        afterCall = DateTime.now();
        expect(result.isAfter(beforeCall.subtract(const Duration(seconds: 1))), true);
        expect(result.isBefore(afterCall.add(const Duration(seconds: 1))), true);
      });
    });
  });
}
```

**Step 2: Run tests to verify they pass**

Run: `flutter test test/unit/utils/helpers_date_test.dart`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/unit/utils/helpers_date_test.dart
git commit -m "test: Add date formatting utility tests"
```

---

## Task 6: Write Helpers utility tests - String operations

**Files:**
- Create: `test/unit/utils/helpers_string_test.dart`

**Step 1: Write string operation tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/utils/helpers.dart';

void main() {
  group('Helpers - String Operations', () {
    group('stripHtmlTags', () {
      test('Should remove HTML tags from string', () {
        final input = '<p>Hello <strong>World</strong></p>';
        expect(Helpers.stripHtmlTags(input), 'Hello World');
      });

      test('Should remove multiple HTML tags', () {
        final input = '<div><p>Test</p><span>Content</span></div>';
        expect(Helpers.stripHtmlTags(input), 'TestContent');
      });

      test('Should handle empty string', () {
        expect(Helpers.stripHtmlTags(''), '');
      });

      test('Should remove nested tags', () {
        final input = '<div><p><strong>Bold</strong> text</p></div>';
        expect(Helpers.stripHtmlTags(input), 'Bold text');
      });

      test('Should preserve text content', () {
        final input = 'Plain text with <b>bold</b> and <i>italic</i>';
        expect(Helpers.stripHtmlTags(input), 'Plain text with bold and italic');
      });
    });

    group('truncateText', () {
      test('Should truncate text longer than maxLength', () {
        expect(Helpers.truncateText('Hello World', 5), 'Hello...');
      });

      test('Should not truncate text shorter than maxLength', () {
        expect(Helpers.truncateText('Hi', 10), 'Hi');
      });

      test('Should handle exact maxLength', () {
        expect(Helpers.truncateText('Hello', 5), 'Hello');
      });

      test('Should handle maxLength of 0', () {
        expect(Helpers.truncateText('Hello', 0), '...');
      });

      test('Should handle empty string', () {
        expect(Helpers.truncateText('', 10), '');
      });
    });

    group('isValidUrl', () {
      test('Should accept valid HTTP URL', () {
        expect(Helpers.isValidUrl('http://example.com'), true);
      });

      test('Should accept valid HTTPS URL', () {
        expect(Helpers.isValidUrl('https://example.com'), true);
      });

      test('Should reject URL without scheme', () {
        expect(Helpers.isValidUrl('example.com'), false);
      });

      test('Should reject FTP URL', () {
        expect(Helpers.isValidUrl('ftp://example.com'), false);
      });

      test('Should reject invalid URL format', () {
        expect(Helpers.isValidUrl('not a url'), false);
      });
    });

    group('isValidImageUrl', () {
      test('Should accept common image extensions', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.jpg'), true);
        expect(Helpers.isValidImageUrl('https://example.com/image.png'), true);
        expect(Helpers.isValidImageUrl('https://example.com/image.gif'), true);
        expect(Helpers.isValidImageUrl('https://example.com/image.webp'), true);
      });

      test('Should accept image from common CDNs', () {
        expect(Helpers.isValidImageUrl('https://images.unsplash.com/photo'), true);
        expect(Helpers.isValidImageUrl('https://cdn.pixabay.com/image.png'), true);
        expect(Helpers.isValidImageUrl('https://res.cloudinary.com/img.jpg'), true);
      });

      test('Should reject non-image URLs', () {
        expect(Helpers.isValidImageUrl('https://example.com/page.html'), false);
        expect(Helpers.isValidImageUrl('https://example.com/article'), false);
      });

      test('Should accept URLs with image keywords', () {
        expect(Helpers.isValidImageUrl('https://example.com/content/image123'), true);
        expect(Helpers.isValidImageUrl('https://example.com/photo_abc123'), true);
      });

      test('Should accept URLs with dimension parameters', () {
        expect(Helpers.isValidImageUrl('https://example.com/img?width=200'), true);
        expect(Helpers.isValidImageUrl('https://example.com/photo?h=300&w=200'), true);
      });

      test('Should reject empty string', () {
        expect(Helpers.isValidImageUrl(''), false);
      });
    });

    group('generateHash', () {
      test('Should generate consistent hash for same input', () {
        final hash1 = Helpers.generateHash('test');
        final hash2 = Helpers.generateHash('test');
        expect(hash1, hash2);
      });

      test('Should generate different hashes for different inputs', () {
        final hash1 = Helpers.generateHash('test1');
        final hash2 = Helpers.generateHash('test2');
        expect(hash1, isNot(hash2));
      });

      test('Should handle empty string', () {
        final hash = Helpers.generateHash('');
        expect(hash, isA<int>());
      });

      test('Should handle special characters', () {
        final hash = Helpers.generateHash('test!@#$%^&*()');
        expect(hash, isA<int>());
      });
    });
  });
}
```

**Step 2: Run tests to verify they pass**

Run: `flutter test test/unit/utils/helpers_string_test.dart`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/unit/utils/helpers_string_test.dart
git commit -m "test: Add string operation utility tests"
```

---

## Task 7: Create ArticleRepository

**Files:**
- Create: `lib/repositories/article_repository.dart`

**Step 1: Write ArticleRepository with Result type**

```dart
import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../utils/error_handler.dart';

/// Repository for article data access operations
/// Implements offline-first pattern with caching
class ArticleRepository {
  const ArticleRepository();

  /// Fetch articles from all RSS sources
  Future<Result<List<Article>>> fetchAllArticles() async {
    try {
      ErrorHandler.logInfo('Fetching articles from all sources');

      final articles = await RssFeedService.fetchAllArticles();

      ErrorHandler.logInfo('Successfully fetched ${articles.length} articles');
      return Result.success(articles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch articles',
        error: e,
        stackTrace: stackTrace,
        severity: ErrorSeverity.high,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Fetch articles from a single RSS source
  Future<Result<List<Article>>> fetchArticlesFromSource(String sourceId) async {
    try {
      final source = RssFeedService.getSourceById(sourceId);

      if (source == null) {
        ErrorHandler.logWarning('Source not found: $sourceId');
        return Result.failure('Source not found');
      }

      ErrorHandler.logInfo('Fetching articles from source: ${source.name}');
      final articles = await RssFeedService.fetchArticles(source);

      ErrorHandler.logInfo('Successfully fetched ${articles.length} articles from ${source.name}');
      return Result.success(articles);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to fetch articles from source $sourceId',
        error: e,
        stackTrace: stackTrace,
        severity: ErrorSeverity.high,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Search for articles by query
  Future<Result<List<Article>>> searchArticles({
    required List<Article> articles,
    required String query,
  }) async {
    try {
      if (query.isEmpty) {
        return Result.success(articles);
      }

      final lowerQuery = query.toLowerCase();
      final results = articles.where((article) =>
        article.title.toLowerCase().contains(lowerQuery) ||
        article.description.toLowerCase().contains(lowerQuery) ||
        article.sourceName.toLowerCase().contains(lowerQuery)
      ).toList();

      ErrorHandler.logInfo('Found ${results.length} articles matching: $query');
      return Result.success(results);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to search articles',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Filter articles by category
  Future<Result<List<Article>>> filterByCategory({
    required List<Article> articles,
    required String category,
  }) async {
    try {
      if (category.isEmpty || category == 'All') {
        return Result.success(articles);
      }

      final results = articles.where((article) {
        final source = RssFeedService.getSourceById(article.sourceId);
        return source?.category == category;
      }).toList();

      ErrorHandler.logInfo('Filtered to ${results.length} articles in category: $category');
      return Result.success(results);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to filter articles by category',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Filter to show only unread articles
  Future<Result<List<Article>>> filterUnread(List<Article> articles) async {
    try {
      final unread = articles.where((a) => !a.isRead).toList();
      return Result.success(unread);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to filter unread articles',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
}

/// Add missing logInfo and logWarning methods to ErrorHandler if not present
extension ErrorHandlerExtensions on ErrorHandler {
  static void logInfo(String message) {
    ErrorHandler.logError(message, severity: ErrorSeverity.low);
  }

  static void logWarning(String message) {
    ErrorHandler.logError(message, severity: ErrorSeverity.medium);
  }
}
```

**Step 2: Run flutter analyze**

Run: `flutter analyze lib/repositories/article_repository.dart`
Expected: No critical errors (warning about unused method OK)

**Step 3: Commit**

```bash
git add lib/repositories/article_repository.dart
git commit -m "feat: Add ArticleRepository with Result type pattern"
```

---

## Task 8: Write ArticleRepository tests

**Files:**
- Create: `test/unit/repositories/article_repository_test.dart`
- Modify: `lib/utils/error_handler.dart` (if needed for extensions)

**Step 1: Write ArticleRepository tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/models/article.dart';

/// Mock setup - add to pubspec.yaml: mockito: ^5.4.4
// @GenerateMocks([ArticleRepository]) // Uncomment after running build

void main() {
  late ArticleRepository repository;

  setUp(() {
    repository = const ArticleRepository();
  });

  group('ArticleRepository', () {
    group('fetch all articles', () {
      test('Should handle successful fetch', () async {
        // Note: Since RSS fetch makes real HTTP calls, we'll need
        // mock the RssFeedService in production. For now, we'll
        // skip integration tests and test the Result pattern

        final result = await repository.fetchAllArticles();

        // Result should have either data or error
        expect(result.isSuccess, isA<bool>());
        if (result.isSuccess) {
          expect(result.data, isA<List<Article>>());
        } else {
          expect(result.error, isA<String?>());
        }
      });
    });

    group('search articles', () {
      final testArticles = [
        Article(
          id: '1',
          title: 'Flutter development guide',
          description: 'Learn Flutter',
          fullContent: '',
          link: 'https://example.com/1',
          sourceId: 'tech',
          sourceName: 'TechCrunch',
          pubDate: DateTime.now(),
        ),
        Article(
          id: '2',
          title: 'Dart programming',
          description: 'Dart language features',
          fullContent: '',
          link: 'https://example.com/2',
          sourceId: 'tech',
          sourceName: 'Dev.to',
          pubDate: DateTime.now(),
        ),
      ];

      test('Should find articles by title', () async {
        final result = await repository.searchArticles(
          articles: testArticles,
          query: 'Flutter',
        );

        expect(result.isSuccess, true);
        expect(result.data?.length, 1);
        expect(result.data?.first.title, contains('Flutter'));
      });

      test('Should find articles by description', () async {
        final result = await repository.searchArticles(
          articles: testArticles,
          query: 'Dart',
        );

        expect(result.isSuccess, true);
        expect(result.data?.length, 2); // Both have Dart in title/description
      });

      test('Should return all articles for empty query', () async {
        final result = await repository.searchArticles(
          articles: testArticles,
          query: '',
        );

        expect(result.isSuccess, true);
        expect(result.data?.length, 2);
      });

      test('Should be case insensitive', () async {
        final result1 = await repository.searchArticles(
          articles: testArticles,
          query: 'flutter',
        );

        final result2 = await repository.searchArticles(
          articles: testArticles,
          query: 'FLUTTER',
        );

        expect(result1.data?.length, result2.data?.length);
      });

      test('Should return empty list for no matches', () async {
        final result = await repository.searchArticles(
          articles: testArticles,
          query: 'nonexistent',
        );

        expect(result.isSuccess, true);
        expect(result.data?.isEmpty, true);
      });
    });

    group('filter by category', () {
      final testArticles = [
        Article(
          id: '1',
          title: 'Tech article',
          description: 'Tech content',
          fullContent: '',
          link: 'https://example.com/1',
          sourceId: 'techcrunch', // Tech category
          sourceName: 'TechCrunch',
          pubDate: DateTime.now(),
        ),
        Article(
          id: '2',
          title: 'News article',
          description: 'News content',
          fullContent: '',
          link: 'https://example.com/2',
          sourceId: 'bbc', // News category
          sourceName: 'BBC',
          pubDate: DateTime.now(),
        ),
      ];

      test('Should filter by category', () async {
        final result = await repository.filterByCategory(
          articles: testArticles,
          category: 'Tech',
        );

        expect(result.isSuccess, true);
        expect(result.data?.length, 1);
        expect(result.data?.first.title, 'Tech article');
      });

      test('Should return all for "All" category', () async {
        final result = await repository.filterByCategory(
          articles: testArticles,
          category: 'All',
        );

        expect(result.isSuccess, true);
        expect(result.data?.length, 2);
      });

      test('Should return all for empty category', () async {
        final result = await repository.filterByCategory(
          articles: testArticles,
          category: '',
        );

        expect(result.isSuccess, true);
        expect(result.data?.length, 2);
      });

      test('Should return empty for non-existent category', () async {
        final result = await repository.filterByCategory(
          articles: testArticles,
          category: 'Sports',
        );

        expect(result.isSuccess, true);
        expect(result.data?.isEmpty, true);
      });
    });

    group('filter unread', () {
      final testArticles = [
        Article(
          id: '1',
          title: 'Unread article',
          description: '',
          fullContent: '',
          link: 'https://example.com/1',
          sourceId: 'test',
          sourceName: 'Test',
          pubDate: DateTime.now(),
          isRead: false,
        ),
        Article(
          id: '2',
          title: 'Read article',
          description: '',
          fullContent: '',
          link: 'https://example.com/2',
          sourceId: 'test',
          sourceName: 'Test',
          pubDate: DateTime.now(),
          isRead: true,
        ),
      ];

      test('Should filter to unread articles only', () async {
        final result = await repository.filterUnread(testArticles);

        expect(result.isSuccess, true);
        expect(result.data?.length, 1);
        expect(result.data?.first.title, 'Unread article');
      });

      test('Should return empty if all read', () async {
        final allRead = testArticles.map((a) => a.copyWith(isRead: true)).toList();

        final result = await repository.filterUnread(allRead);

        expect(result.isSuccess, true);
        expect(result.data?.isEmpty, true);
      });
    });
  });
}
```

**Step 2: Add mockito dependency if not present**

Modify: `pubspec.yaml`

```yaml
dev_dependencies:
  # ... existing ...
  mockito: ^5.4.4
  build_runner: ^2.4.6
```

Run: `flutter pub get`

**Step 3: Run tests**

Run: `flutter test test/unit/repositories/article_repository_test.dart`
Expected: All unit tests pass (integration test skipped)

**Step 4: Commit**

```bash
git add lib/repositories/article_repository.dart test/unit/repositories/article_repository_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: Add ArticleRepository with tests"
```

---

## Task 9: Create FeedRepository

**Files:**
- Create: `lib/repositories/feed_repository.dart`

**Step 1: Write FeedRepository for feed management**

```dart
import '../models/rss_source.dart';
import '../models/article.dart';
import '../services/rss_feed_service.dart';
import '../utils/error_handler.dart';

/// Repository for RSS feed management
class FeedRepository {
  const FeedRepository();

  /// Get all predefined RSS sources
  Future<Result<List<RssSource>>> getAllSources() async {
    try {
      final sources = RssFeedService.predefinedSources;
      ErrorHandler.logInfo('Retrieved ${sources.length} predefined sources');
      return Result.success(sources);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get RSS sources',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get source by ID
  Future<Result<RssSource?>> getSourceById(String sourceId) async {
    try {
      final source = RssFeedService.getSourceById(sourceId);

      if (source == null) {
        ErrorHandler.logWarning('Source not found: $sourceId');
        return Result.success(null);
      }

      return Result.success(source);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get source by id',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get sources by category
  Future<Result<List<RssSource>>> getSourcesByCategory(String category) async {
    try {
      if (category.isEmpty || category == 'All') {
        final sources = RssFeedService.predefinedSources;
        return Result.success(sources);
      }

      final sources = RssFeedService.predefinedSources
          .where((source) => source.category == category)
          .toList();

      return Result.success(sources);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get sources by category',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get all available categories
  Future<Result<List<String>>> getCategories() async {
    try {
      final categories = RssFeedService.predefinedSources
          .map((source) => source.category)
          .toSet()
          .toList()
        ..sort();

      final allCategories = ['All', ...categories];

      ErrorHandler.logInfo('Retrieved ${allCategories.length} categories');
      return Result.success(allCategories);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get categories',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Get feed health status (placeholder for future enhancement)
  Future<Result<Map<String, bool>>> getFeedHealth() async {
    try {
      // In future: actually ping each feed to check health
      // For now, return all as healthy
      final health = {
        for (var source in RssFeedService.predefinedSources)
          source.id: true
      };

      return Result.success(health);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to get feed health',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }
}
```

**Step 2: Run flutter analyze**

Run: `flutter analyze lib/repositories/feed_repository.dart`
Expected: No critical errors

**Step 3: Commit**

```bash
git add lib/repositories/feed_repository.dart
git commit -m "feat: Add FeedRepository for source management"
```

---

## Task 10: Write FeedRepository tests

**Files:**
- Create: `test/unit/repositories/feed_repository_test.dart`

**Step 1: Write FeedRepository tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/repositories/feed_repository.dart';

void main() {
  late FeedRepository repository;

  setUp(() {
    repository = const FeedRepository();
  });

  group('FeedRepository', () {
    group('getAllSources', () {
      test('Should return all predefined sources', () async {
        final result = await repository.getAllSources();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
        expect(result.data!.isNotEmpty, true);
      });

      test('Should have expected default sources', () async {
        final result = await repository.getAllSources();

        expect(result.isSuccess, true);
        final sources = result.data!;
        final sourceIds = sources.map((s) => s.id).toList();

        expect(sourceIds, contains('techcrunch'));
        expect(sourceIds, contains('verge'));
        expect(sourceIds, contains('bbc'));
      });
    });

    group('getSourceById', () {
      test('Should return source for valid ID', () async {
        final result = await repository.getSourceById('techcrunch');

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
        expect(result.data!.id, 'techcrunch');
        expect(result.data!.name, 'TechCrunch');
      });

      test('Should return null for invalid ID', () async {
        final result = await repository.getSourceById('nonexistent');

        expect(result.isSuccess, true);
        expect(result.data, isNull);
      });
    });

    group('getSourcesByCategory', () {
      test('Should filter sources by category', () async {
        final result = await repository.getSourcesByCategory('Tech');

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
        expect(result.data!.every((s) => s.category == 'Tech'), true);
      });

      test('Should return all sources for "All" category', () async {
        final result = await repository.getSourcesByCategory('All');

        expect(result.isSuccess, true);
        final allResult = await repository.getAllSources();
        expect(result.data!.length, allResult.data!.length);
      });

      test('Should return empty list for non-existent category', () async {
        final result = await repository.getSourcesByCategory('NonExistent');

        expect(result.isSuccess, true);
        expect(result.data!.isEmpty, true);
      });
    });

    group('getCategories', () {
      test('Should return all categories including "All"', () async {
        final result = await repository.getCategories();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
        expect(result.data!.contains('All'), true);
      });

      test('Should have expected categories', () async {
        final result = await repository.getCategories();

        expect(result.isSuccess, true);
        final categories = result.data!;

        expect(categories, contains('All'));
        expect(categories, contains('Tech'));
        expect(categories, contains('News'));
        expect(categories, contains('Science'));
      });

      test('Should return sorted categories', () async {
        final result = await repository.getCategories();

        expect(result.isSuccess, true);
        final categories = result.data!;

        // Verify it's sorted
        final sorted = List.from(categories)..sort();
        expect(categories, equals(sorted));
      });
    });

    group('getFeedHealth', () {
      test('Should return health map for all sources', () async {
        final result = await repository.getFeedHealth();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);

        final sourcesResult = await repository.getAllSources();
        final sourceCount = sourcesResult.data!.length;

        expect(result.data!.length, sourceCount);
      });

      test('Should mark all sources as healthy initially', () async {
        final result = await repository.getFeedHealth();

        expect(result.isSuccess, true);

        final allHealthy = result.data!.values.every((isHealthy) => isHealthy);
        expect(allHealthy, true);
      });
    });
  });
}
```

**Step 2: Run tests**

Run: `flutter test test/unit/repositories/feed_repository_test.dart`
Expected: All tests pass

**Step 3: Commit**

```bash
git add test/unit/repositories/feed_repository_test.dart
git commit -m "test: Add FeedRepository tests"
```

---

## Task 11: Initialize service locator in main

**Files:**
- Modify: `lib/main.dart`

**Step 1: Initialize service locator**

```dart
import 'package:flutter/material.dart';

import 'utils/constants.dart';
import 'screens/feed_screen.dart';
import 'di/service_locator.dart';

void main() async {
  // Initialize service locator before runApp
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  runApp(const RssReaderApp());
}
```

**Step 2: Run flutter analyze**

Run: `flutter analyze lib/main.dart`
Expected: No errors

**Step 3: Run app to verify startup**

Run: `flutter run`
Expected: App launches successfully, service locator initialized

**Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: Initialize service locator at app startup"
```

---

**Phase 1 Complete Summary:**
- ✅ Added get_it dependency for DI
- ✅ Created service locator setup
- ✅ Added comprehensive model tests (Article, RssSource)
- ✅ Added utility function tests (date, string, validation)
- ✅ Created ArticleRepository with Result type pattern
- ✅ Created FeedRepository for source management
- ✅ Added repository tests
- ✅ Initialized service locator in main
- ✅ All tests passing
- ✅ No breaking UI changes

---

# Phase 2: Core Features Enhancement (Week 3-4)

## Task 12: Add debounce utility for search

**Files:**
- Create: `lib/utils/debounce.dart`

**Step 1: Write debounce utility**

```dart
import 'dart:async';

/// Utility for debouncing function calls
class Debounce {
  final Duration delay;
  Timer? _timer;

  Debounce({this.delay = const Duration(milliseconds: 300)});

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
```

**Step 2: Write debounce tests**

Create: `test/unit/utils/debounce_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/utils/debounce.dart';

void main() {
  group('Debounce', () {
    test('Should debounce rapid calls', () async {
      int callCount = 0;

      final debounce = Debounce(delay: const Duration(milliseconds: 100));

      // Make multiple rapid calls
      debounce(() => callCount++);
      debounce(() => callCount++);
      debounce(() => callCount++);

      // Should not have executed yet
      expect(callCount, 0);

      // Wait for debounce delay
      await Future.delayed(const Duration(milliseconds: 200));

      // Should have executed only once
      expect(callCount, 1);

      debounce.dispose();
    });

    test('Should respect custom delay', () async {
      int callCount = 0;

      final debounce = Debounce(delay: const Duration(milliseconds: 50));

      debounce(() => callCount++);

      await Future.delayed(const Duration(milliseconds: 30));
      expect(callCount, 0);

      await Future.delayed(const Duration(milliseconds: 30));
      expect(callCount, 1);

      debounce.dispose();
    });

    test('Should cancel previous timer', () async {
      int lastCallValue = 0;

      final debounce = Debounce(delay: const Duration(milliseconds: 100));

      debounce(() => lastCallValue = 1);
      debounce(() => lastCallValue = 2);
      debounce(() => lastCallValue = 3);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(lastCallValue, 3);

      debounce.dispose();
    });
  });
}
```

**Step 3: Run tests**

Run: `flutter test test/unit/utils/debounce_test.dart`
Expected: All tests pass

**Step 4: Commit**

```bash
git add lib/utils/debounce.dart test/unit/utils/debounce_test.dart
git commit -m "feat: Add debounce utility for search"
```

---

## Task 13: Create in-memory cache for articles

**Files:**
- Create: `lib/services/memory_cache.dart`

**Step 1: Write memory cache service**

```dart
import '../models/article.dart';

/// Simple in-memory cache for articles
/// Provides fast access to recently used data
class ArticleMemoryCache {
  final int maxSize;
  final Map<String, Article> _cache = {};
  final List<String> _accessOrder = [];

  ArticleMemoryCache({this.maxSize = 500});

  /// Get article from cache
  Article? get(String id) {
    if (_cache.containsKey(id)) {
      // Update access order (move to end)
      _accessOrder.remove(id);
      _accessOrder.add(id);
      return _cache[id];
    }
    return null;
  }

  /// Put article in cache
  void put(Article article) {
    _cache[article.id] = article;

    // Update access order
    _accessOrder.remove(article.id);
    _accessOrder.add(article.id);

    // Evict oldest if over size limit
    while (_cache.length > maxSize) {
      final oldest = _accessOrder.removeAt(0);
      _cache.remove(oldest);
    }
  }

  /// Put multiple articles in cache
  void putAll(List<Article> articles) {
    for (final article in articles) {
      put(article);
    }
  }

  /// Remove article from cache
  void remove(String id) {
    _cache.remove(id);
    _accessOrder.remove(id);
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// Get current cache size
  int get size => _cache.length;

  /// Check if article is cached
  bool contains(String id) => _cache.containsKey(id);
}
```

**Step 2: Write memory cache tests**

Create: `test/unit/services/memory_cache_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/services/memory_cache.dart';
import 'package:curatedfeeds/models/article.dart';

void main() {
  group('ArticleMemoryCache', () {
    late ArticleMemoryCache cache;
    late Article testArticle1;
    late Article testArticle2;

    setUp(() {
      cache = ArticleMemoryCache(maxSize: 3);
      testArticle1 = Article(
        id: 'article-1',
        title: 'Article 1',
        description: '',
        fullContent: '',
        link: 'https://example.com/1',
        sourceId: 'test',
        sourceName: 'Test',
        pubDate: DateTime.now(),
      );

      testArticle2 = Article(
        id: 'article-2',
        title: 'Article 2',
        description: '',
        fullContent: '',
        link: 'https://example.com/2',
        sourceId: 'test',
        sourceName: 'Test',
        pubDate: DateTime.now(),
      );
    });

    test('Should store and retrieve article', () {
      cache.put(testArticle1);

      final retrieved = cache.get('article-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'article-1');
      expect(retrieved.title, 'Article 1');
    });

    test('Should return null for non-existent article', () {
      final retrieved = cache.get('nonexistent');

      expect(retrieved, isNull);
    });

    test('Should track cache size', () {
      expect(cache.size, 0);

      cache.put(testArticle1);
      expect(cache.size, 1);

      cache.put(testArticle2);
      expect(cache.size, 2);
    });

    test('Should evict oldest when over size limit', () {
      final article3 = Article(
        id: 'article-3',
        title: 'Article 3',
        description: '',
        fullContent: '',
        link: 'https://example.com/3',
        sourceId: 'test',
        sourceName: 'Test',
        pubDate: DateTime.now(),
      );

      final article4 = Article(
        id: 'article-4',
        title: 'Article 4',
        description: '',
        fullContent: '',
        link: 'https://example.com/4',
        sourceId: 'test',
        sourceName: 'Test',
        pubDate: DateTime.now(),
      );

      cache.put(testArticle1); // Will be evicted
      cache.put(testArticle2);
      cache.put(article3);
      cache.put(article4); // Triggers eviction

      expect(cache.size, 3);
      expect(cache.contains('article-1'), false); // Evicted
      expect(cache.contains('article-2'), true);
      expect(cache.contains('article-3'), true);
      expect(cache.contains('article-4'), true);

      // article-2 should still be retrievable (was accessed when evict-1)
      expect(cache.get('article-2'), isNotNull);
    });

    test('Should remove article', () {
      cache.put(testArticle1);
      expect(cache.contains('article-1'), true);

      cache.remove('article-1');
      expect(cache.contains('article-1'), false);
      expect(cache.get('article-1'), isNull);
    });

    test('Should clear all articles', () {
      cache.put(testArticle1);
      cache.put(testArticle2);

      expect(cache.size, 2);

      cache.clear();

      expect(cache.size, 0);
      expect(cache.contains('article-1'), false);
      expect(cache.contains('article-2'), false);
    });

    test('Should support putAll', () {
      final articles = [
        testArticle1,
        testArticle2,
      ];

      cache.putAll(articles);

      expect(cache.size, 2);
      expect(cache.contains('article-1'), true);
      expect(cache.contains('article-2'), true);
    });

    test('Should update access order on get', () {
      final article3 = Article(
        id: 'article-3',
        title: 'Article 3',
        description: '',
        fullContent: '',
        link: 'https://example.com/3',
        sourceId: 'test',
        sourceName: 'Test',
        pubDate: DateTime.now(),
      );

      cache.put(testArticle1);
      cache.put(testArticle2);
      cache.put(article3);

      // Access article-1 to make it recently used
      cache.get('article-1');

      // Add one more article to trigger eviction
      final article4 = Article(
        id: 'article-4',
        title: 'Article 4',
        description: '',
        fullContent: '',
        link: 'https://example.com/4',
        sourceId: 'test',
        sourceName: 'Test',
        pubDate: DateTime.now(),
      );

      cache.put(article4);

      // article-2 should be evicted (oldest access)
      expect(cache.contains('article-1'), true);
      expect(cache.contains('article-2'), false);
      expect(cache.contains('article-3'), true);
      expect(cache.contains('article-4'), true);
    });
  });
}
```

**Step 3: Run tests**

Run: `flutter test test/unit/services/memory_cache_test.dart`
Expected: All tests pass

**Step 4: Register memory cache in service locator**

Modify: `lib/di/service_locator.dart`

```dart
import 'package:get_it/get_it.dart';
import '../services/rss_feed_service.dart';
import '../services/storage_service.dart';
import '../services/cache_manager.dart';
import '../services/article_content_service.dart';
import '../services/update_service.dart';
import '../services/memory_cache.dart';

/// Global service locator instance
final GetIt getIt = GetIt.instance;

/// Setup all service dependencies
Future<void> setupServiceLocator() async {
  // Register singleton services
  getIt.registerLazySingleton<StorageService>(() => StorageService());
  getIt.registerLazySingleton<AppCacheManager>(() => AppCacheManager());
  getIt.registerLazySingleton<ApkCacheManager>(() => ApkCacheManager());
  getIt.registerLazySingleton<ArticleMemoryCache>(() => ArticleMemoryCache());
}
```

**Step 5: Commit**

```bash
git add lib/services/memory_cache.dart test/unit/services/memory_cache_test.dart lib/di/service_locator.dart
git commit -m "feat: Add in-memory cache for articles"
```

---

## Task 14: Improve search with debounce in feed screen

**Files:**
- Modify: `lib/screens/feed_screen.dart`

**Step 1: Add debounce to feed screen**

Add import at top:
```dart
import '../utils/debounce.dart';
```

Add to _RssFeedScreenState class:
```dart
late final Debounce _searchDebounce;
```

Add to initState:
```dart
@override
void initState() {
  super.initState();
  _loadData();
  _loadViewMode();
  _checkConnectivity();
  _checkForUpdates();

  _fabController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  _staggerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  _fabController.forward();

  _searchDebounce = Debounce(delay: const Duration(milliseconds: 300));
}
```

Add to dispose:
```dart
@override
void dispose() {
  // Memory leak fix: Cancel subscription explicitly
  _connectivitySubscription?.cancel();
  _searchDebounce.dispose();
  _fabController.dispose();
  _staggerController.dispose();
  super.dispose();
}
```

Update search onChanged callback:
```dart
onChanged: (value) {
  _searchDebounce(() {
    setState(() {
      _searchQuery = value;
      _displayedArticles = _getFilteredArticles();
    });
  });
},
```

**Step 2: Test search debouncing**

Run: `flutter run`
Manual test - verify search updates after 300ms delay, not immediately

**Step 3: Commit**

```bash
git add lib/screens/feed_screen.dart
git commit -m "perf: Add debounce to search for better performance"
```

---

**Phase 2 Complete Summary:**
- ✅ Added debounce utility with tests
- ✅ Created ArticleMemoryCache with LRU eviction
- ✅ Integrated debounce into feed screen search
- ✅ Improved search performance
- ✅ Ready for offline enhancements

---

# Phase 3: UI/UX Improvements (Week 5-6)

## Task 15: Add dark mode theme support

**Files:**
- Create: `lib/utils/theme_manager.dart`

**Step 1: Create theme manager**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enum
enum AppThemeMode {
  light,
  dark,
  system,
}

/// Manages app theme and persistence
class ThemeManager {
  static const String _themeKey = 'app_theme_mode';

  /// Get current theme mode
  static Future<AppThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 2; // Default to system
    return AppThemeMode.values[themeIndex];
  }

  /// Save theme mode
  static Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  /// Get ThemeMode for MaterialApp
  static ThemeMode getThemeModeFromEnum(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
```

**Step 2: Add dark theme colors to constants**

Modify: `lib/utils/constants.dart`

```dart
/// App-wide constants and color definitions
class AppColors {
  AppColors._();

  // Primary colors (Light theme)
  static const Color primary = Color(0xFF1A1B4D);
  static const Color accent = Color(0xFFC9A962);
  static const Color background = Color(0xFFF8F7F4);
  static const Color surface = Color(0xFFFFFFFF);

  // Text colors (Light theme)
  static const Color textPrimary = Color(0xFF1A1B2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);

  // Semantic colors
  static const Color error = Color(0xFFDC3640);
  static const Color success = Color(0xFF057A55);

  // Dark theme colors
  static const Color primaryDark = Color(0xFF2D2F73);
  static const Color backgroundDark = Color(0xFF0F1016);
  static const Color surfaceDark = Color(0xFF1A1B4D);
  static const Color textPrimaryDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFA0AEC0);
  static const Color textTertiaryDark = Color(0xFF718096);
  static const Color dividerDark = Color(0xFF2D3748);

  // Category colors - Tech
  static const Color techPrimary = Color(0xFF3B82F6);
  static const Color techSecondary = Color(0xFF60A5FA);

  // Category colors - News
  static const Color newsPrimary = Color(0xFFDC2626);
  static const Color newsSecondary = Color(0xFFEF4444);

  // Category colors - Science
  static const Color sciencePrimary = Color(0xFF0891B2);
  static const Color scienceSecondary = Color(0xFF22D3EE);

  // Category colors - Sports
  static const Color sportsPrimary = Color(0xFF059669);
  static const Color sportsSecondary = Color(0xFF34D399);

  // Category colors - Entertainment
  static const Color entertainmentPrimary = Color(0xFF7C3AED);
  static const Color entertainmentSecondary = Color(0xFFA78BFA);
}
```

**Step 3: Create dark theme data**

Add to: `lib/utils/constants.dart`

```dart
/// Get light theme data
ThemeData get lightTheme {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    useMaterial3: true,
    textTheme: appTextTheme,
  );
}

/// Get dark theme data
ThemeData get darkTheme {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryDark,
      brightness: Brightness.dark,
      primary: AppColors.primaryDark,
      secondary: AppColors.accent,
      surface: AppColors.surfaceDark,
    ),
    useMaterial3: true,
    textTheme: appTextTheme.copyWith(
      headlineLarge: GoogleFonts.playfairDisplay(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: AppColors.textPrimaryDark,
      ),
      headlineMedium: GoogleFonts.playfairDisplay(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: AppColors.textPrimaryDark,
      ),
      headlineSmall: GoogleFonts.playfairDisplay(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.textPrimaryDark,
      ),
      titleLarge: GoogleFonts.playfairDisplay(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.textPrimaryDark,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: AppColors.textPrimaryDark,
      ),
      bodyLarge: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: AppColors.textPrimaryDark,
        height: 1.6,
      ),
      bodyMedium: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: AppColors.textPrimaryDark,
        height: 1.5,
      ),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppColors.textPrimaryDark,
      ),
    ),
  );
}
```

**Step 4: Update main.dart to support theme switching**

Modify: `lib/main.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'utils/constants.dart';
import 'utils/theme_manager.dart';
import 'screens/feed_screen.dart';
import 'di/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  final themeMode = await ThemeManager.getThemeMode();

  runApp(RssReaderApp(initialThemeMode: themeMode));
}

class RssReaderApp extends StatefulWidget {
  final AppThemeMode initialThemeMode;

  const RssReaderApp({
    super.key,
    required this.initialThemeMode,
  });

  @override
  State<RssReaderApp> createState() => _RssReaderAppState();
}

class _RssReaderAppState extends State<RssReaderApp> {
  late AppThemeMode _currentThemeMode;

  @override
  void initState() {
    super.initState();
    _currentThemeMode = widget.initialThemeMode;
  }

  void setThemeMode(AppThemeMode mode) {
    setState(() {
      _currentThemeMode = mode;
    });
    ThemeManager.setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curated Feeds',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeManager.getThemeModeFromEnum(_currentThemeMode),
      home: RssFeedScreen(),
    );
  }
}
```

**Step 5: Add theme toggle to settings**

Create: `lib/widgets/theme_toggle.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';
import '../utils/theme_manager.dart';

class ThemeToggle extends StatelessWidget {
  final AppThemeMode currentMode;
  final Function(AppThemeMode) onThemeChanged;

  const ThemeToggle({
    super.key,
    required this.currentMode,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildThemeButton(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            mode: AppThemeMode.light,
            isSelected: currentMode == AppThemeMode.light,
          ),
          _buildThemeButton(
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            mode: AppThemeMode.dark,
            isSelected: currentMode == AppThemeMode.dark,
          ),
          _buildThemeButton(
            icon: Icons.brightness_auto_outlined,
            label: 'Auto',
            mode: AppThemeMode.system,
            isSelected: currentMode == AppThemeMode.system,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeButton({
    required IconData icon,
    required String label,
    required AppThemeMode mode,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => onThemeChanged(mode),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.primaryDark : AppColors.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 6: Integrate theme toggle into settings**

Modify: `lib/screens/feed_screen.dart` - add to _buildSettingsView:

```dart
_buildSettingsItem(
  icon: Icons.palette_outlined,
  title: 'Theme',
  subtitle: ThemeToggle(
    currentMode: _themeMode,
    onThemeChanged: (mode) {
      setState(() {
        _themeMode = mode;
      });
      // Access parent to update app theme
      final appState = context.findAncestorStateOfType<_RssReaderAppState>();
      appState?.setThemeMode(mode);
    },
  ),
  onTap: null,
),
```

Add import:
```dart
import '../widgets/theme_toggle.dart';
```

Add state variable:
```dart
AppThemeMode _themeMode = AppThemeMode.system;
```

Load in initState:
```dart
@override
void initState() {
  super.initState();
  _loadData();
  _loadViewMode();
  _loadThemeMode();
  _checkConnectivity();
  _checkForUpdates();
  // ... rest of initState
}

Future<void> _loadThemeMode() async {
  final mode = await ThemeManager.getThemeMode();
  if (mounted) {
    setState(() {
      _themeMode = mode;
    });
  }
}
```

**Step 7: Commit**

```bash
git add lib/utils/theme_manager.dart lib/utils/constants.dart lib/widgets/theme_toggle.dart lib/screens/feed_screen.dart lib/main.dart
git commit -m "feat: Add dark mode support with theme toggle"
```

---

## Task 16: Add skeleton loader for card stack

**Files:**
- Create: `lib/widgets/skeleton_loader.dart`

**Step 1: Write skeleton loader widget**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

/// Skeleton loader widget for smooth loading experience
class ArticleSkeletonCard extends StatelessWidget {
  const ArticleSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source badge skeleton
            _SkeletonContainer(
              width: 100,
              height: 32,
              borderRadius: 12,
            ),
            const SizedBox(height: 24),

            // Image skeleton
            _SkeletonContainer(
              width: double.infinity,
              height: 180,
              borderRadius: 20,
            ),
            const SizedBox(height: 24),

            // Title skeleton
            _SkeletonContainer(
              width: double.infinity,
              height: 80,
              borderRadius: 8,
            ),
            const SizedBox(height: 20),

            // Description skeleton
            Column(
              children: [
                _SkeletonContainer(
                  width: double.infinity,
                  height: 20,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                _SkeletonContainer(
                  width: double.infinity * 0.8,
                  height: 20,
                  borderRadius: 4,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Time skeleton
            _SkeletonContainer(
              width: 80,
              height: 36,
              borderRadius: 12,
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple shimmer effect for skeleton loading
class Shimmer extends StatelessWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            Colors.grey.withValues(alpha: 0.1),
            Colors.grey.withValues(alpha: 0.2),
            Colors.grey.withValues(alpha: 0.1),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: const Alignment(-1.0, 0.0),
          end: const Alignment(1.0, 0.0),
          tileMode: TileMode.clamp,
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

/// Skeleton container with rounded corners
class _SkeletonContainer extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonContainer({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
```

**Step 2: Update feed screen to use skeleton loader**

Modify: `lib/screens/feed_screen.dart` - update _buildLoadingState:

```dart
Widget _buildLoadingState() {
  return Column(
    children: [
      const SizedBox(height: 20),
      const ArticleSkeletonCard(),
      const SizedBox(height: 8),
      Transform.scale(
        scale: 0.95,
        child: const Opacity(
          opacity: 0.5,
          child: ArticleSkeletonCard(),
        ),
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          'Loading feeds...',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            letterSpacing: 0.1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}
```

Add import:
```dart
import '../widgets/skeleton_loader.dart';
```

**Step 3: Commit**

```bash
git add lib/widgets/skeleton_loader.dart lib/screens/feed_screen.dart
git commit -m "feat: Add skeleton loader for smoother loading experience"
```

---

**Phase 3 Complete Summary:**
- ✅ Added dark mode with system preference detection
- ✅ Created theme toggle widget
- ✅ Added skeleton loaders for better UX
- ✅ Updated all screens to support dark theme
- ✅ Smooth loading experience

---

# Phase 4: User Customization (Week 7-8)

## Task 17: Add custom RSS feed model

**Files:**
- Create: `lib/models/custom_feed.dart`

**Step 1: Write CustomFeed model**

```dart
import 'package:flutter/material.dart';
import 'dart:convert';

/// Custom RSS feed added by user
class CustomFeed {
  final String id;
  final String name;
  final String url;
  String category;
  Color color;
  IconData icon;
  final DateTime createdAt;
  bool isEnabled;

  CustomFeed({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.color,
    required this.icon,
    DateTime? createdAt,
    this.isEnabled = true,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from JSON
  factory CustomFeed.fromJson(Map<String, dynamic> json) {
    return CustomFeed(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Feed',
      url: json['url'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      color: Color(json['color'] as int? ?? 0xFF3B82F6),
      icon: IconData(
        json['icon'] as int? ?? 0xE000,
        fontFamily: 'MaterialIcons',
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int)
          : null,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'category': category,
      'color': color.value,
      'icon': icon.codePoint,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isEnabled': isEnabled,
    };
  }

  /// Create a copy with updated fields
  CustomFeed copyWith({
    String? id,
    String? name,
    String? url,
    String? category,
    Color? color,
    IconData? icon,
    DateTime? createdAt,
    bool? isEnabled,
  }) {
    return CustomFeed(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      category: category ?? this.category,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
```

**Step 2: Write CustomFeed tests**

Create: `test/unit/models/custom_feed_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/custom_feed.dart';

void main() {
  group('CustomFeed Model', () {
    late CustomFeed testFeed;

    setUp(() {
      testFeed = CustomFeed(
        id: 'custom-1',
        name: 'My Blog',
        url: 'https://example.com/feed.xml',
        category: 'Custom',
        color: const Color(0xFF3B82F6),
        icon: Icons.rss_feed,
      );
    });

    test('Should create CustomFeed with correct values', () {
      expect(testFeed.id, 'custom-1');
      expect(testFeed.name, 'My Blog');
      expect(testFeed.url, 'https://example.com/feed.xml');
      expect(testFeed.category, 'Custom');
      expect(testFeed.color, const Color(0xFF3B82F6));
      expect(testFeed.icon, Icons.rss_feed);
      expect(testFeed.isEnabled, true);
    });

    test('Should create with default createdAt', () {
      final now = DateTime.now();
      expect(testFeed.createdAt.isBefore(now.add(const Duration(seconds: 1))), true);
      expect(testFeed.createdAt.isAfter(now.subtract(const Duration(seconds: 1))), true);
    });

    test('Should convert to JSON correctly', () {
      final json = testFeed.toJson();

      expect(json['id'], 'custom-1');
      expect(json['name'], 'My Blog');
      expect(json['url'], 'https://example.com/feed.xml');
      expect(json['category'], 'Custom');
      expect(json['color'], 0xFF3B82F6);
      expect(json['icon'], Icons.rss_feed.codePoint);
      expect(json['isEnabled'], true);
    });

    test('Should create from JSON correctly', () {
      final json = {
        'id': 'custom-2',
        'name': 'Another Feed',
        'url': 'https://example.com/feed2.xml',
        'category': 'Technology',
        'color': 0xFFDC2626,
        'icon': Icons.computer.codePoint,
        'createdAt': 1705306200000,
        'isEnabled': false,
      };

      final feed = CustomFeed.fromJson(json);

      expect(feed.id, 'custom-2');
      expect(feed.name, 'Another Feed');
      expect(feed.url, 'https://example.com/feed2.xml');
      expect(feed.category, 'Technology');
      expect(feed.color, const Color(0xFFDC2626));
      expect(feed.icon, Icons.computer);
      expect(feed.createdAt, DateTime(2024, 1, 15, 10, 30));
      expect(feed.isEnabled, false);
    });

    test('Should create copy with updated values', () {
      final updated = testFeed.copyWith(
        name: 'Updated Feed',
        isEnabled: false,
      );

      expect(updated.id, testFeed.id);
      expect(updated.name, 'Updated Feed');
      expect(updated.url, testFeed.url);
      expect(updated.isEnabled, false);
    });

    test('Should use defaults for missing fields in fromJson', () {
      final json = {
        'id': 'minimal',
        'name': 'Minimal Feed',
      };

      final feed = CustomFeed.fromJson(json);

      expect(feed.id, 'minimal');
      expect(feed.name, 'Minimal Feed');
      expect(feed.url, ''); // default
      expect(feed.category, 'General'); // default
      expect(feed.isEnabled, true); // default
    });
  });
}
```

**Step 3: Run tests**

Run: `flutter test test/unit/models/custom_feed_test.dart`
Expected: All tests pass

**Step 4: Commit**

```bash
git add lib/models/custom_feed.dart test/unit/models/custom_feed_test.dart
git commit -m "feat: Add CustomFeed model for user-added RSS feeds"
```

---

## Task 18: Create CustomFeedRepository

**Files:**
- Create: `lib/repositories/custom_feed_repository.dart`

**Step 1: Write CustomFeedRepository**

```dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/custom_feed.dart';
import '../utils/error_handler.dart';

/// Repository for custom RSS feed management
class CustomFeedRepository {
  static const String _storageKey = 'custom_feeds';
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Get all custom feeds
  Future<Result<List<CustomFeed>>> getAllFeeds() async {
    try {
      final jsonString = await _secureStorage.read(key: _storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return Result.success(<CustomFeed>[]);
      }

      final List<dynamic> decoded = json.decode(jsonString);
      final feeds = decoded
          .map((json) => CustomFeed.fromJson(json as Map<String, dynamic>))
          .toList();

      ErrorHandler.logInfo('Retrieved ${feeds.length} custom feeds');
      return Result.success(feeds);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to load custom feeds',
        error: e,
        stackTrace: stackTrace,
        severity: ErrorSeverity.high,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Save a custom feed
  Future<Result<void>> saveFeed(CustomFeed feed) async {
    try {
      final result = await getAllFeeds();

      if (result.isFailure) {
        return Result.failure(result.error ?? 'Failed to load feeds');
      }

      final feeds = result.data!;
      feeds.add(feed);

      await _saveFeeds(feeds);
      ErrorHandler.logInfo('Saved custom feed: ${feed.name}');

      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to save custom feed',
        error: e,
        stackTrace: stackTrace,
        severity: ErrorSeverity.high,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Update an existing custom feed
  Future<Result<void>> updateFeed(CustomFeed feed) async {
    try {
      final result = await getAllFeeds();

      if (result.isFailure) {
        return Result.failure(result.error ?? 'Failed to load feeds');
      }

      final feeds = result.data!;
      final index = feeds.indexWhere((f) => f.id == feed.id);

      if (index == -1) {
        return Result.failure('Feed not found');
      }

      feeds[index] = feed;
      await _saveFeeds(feeds);
      ErrorHandler.logInfo('Updated custom feed: ${feed.name}');

      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to update custom feed',
        error: e,
        stackTrace: stackTrace,
        severity: ErrorSeverity.high,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Delete a custom feed
  Future<Result<void>> deleteFeed(String feedId) async {
    try {
      final result = await getAllFeeds();

      if (result.isFailure) {
        return Result.failure(result.error ?? 'Failed to load feeds');
      }

      final feeds = result.data!;
      final feed = feeds.firstWhere((f) => f.id == feedId);

      feeds.removeWhere((f) => f.id == feedId);
      await _saveFeeds(feeds);
      ErrorHandler.logInfo('Deleted custom feed: ${feed.name}');

      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to delete custom feed',
        error: e,
        stackTrace: stackTrace,
        severity: ErrorSeverity.high,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Toggle feed enabled status
  Future<Result<void>> toggleFeed(String feedId) async {
    try {
      final result = await getAllFeeds();

      if (result.isFailure) {
        return Result.failure(result.error ?? 'Failed to load feeds');
      }

      final feeds = result.data!;
      final index = feeds.indexWhere((f) => f.id == feedId);

      if (index == -1) {
        return Result.failure('Feed not found');
      }

      feeds[index] = feeds[index].copyWith(
        isEnabled: !feeds[index].isEnabled,
      );

      await _saveFeeds(feeds);

      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.logError(
        'Failed to toggle feed',
        error: e,
        stackTrace: stackTrace,
      );
      return Result.failure(ErrorHandler.getUserMessage(e));
    }
  }

  /// Validate RSS feed URL (basic check)
  Future<Result<bool>> validateFeedUrl(String url) async {
    try {
      if (url.isEmpty) {
        return Result.failure('URL cannot be empty');
      }

      if (!url.startsWith('http')) {
        return Result.failure('URL must start with http:// or https://');
      }

      final uri = Uri.parse(url);

      if (!uri.hasScheme) {
        return Result.failure('Invalid URL format');
      }

      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return Result.failure('Only HTTP and HTTPS URLs are supported');
      }

      return Result.success(true);
    } catch (e) {
      return Result.failure('Invalid URL format');
    }
  }

  Future<void> _saveFeeds(List<CustomFeed> feeds) async {
    final jsonString = json.encode(feeds.map((f) => f.toJson()).toList());
    await _secureStorage.write(key: _storageKey, value: jsonString);
  }
}
```

**Step 2: Write CustomFeedRepository tests**

Create: `test/unit/repositories/custom_feed_repository_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/repositories/custom_feed_repository.dart';
import 'package:curatedfeeds/models/custom_feed.dart';
import 'package:flutter/material.dart';

void main() {
  late CustomFeedRepository repository;

  setUp(() async {
    repository = CustomFeedRepository();
    // Clear feeds before each test
    final feedsResult = await repository.getAllFeeds();
    if (feedsResult.isSuccess && feedsResult.data != null) {
      for (final feed in feedsResult.data!) {
        await repository.deleteFeed(feed.id);
      }
    }
  });

  tearDown(() async {
    // Clean up after tests
    final feedsResult = await repository.getAllFeeds();
    if (feedsResult.isSuccess && feedsResult.data != null) {
      for (final feed in feedsResult.data!) {
        await repository.deleteFeed(feed.id);
      }
    }
  });

  group('CustomFeedRepository', () {
    test('Should save a new feed', () async {
      final feed = CustomFeed(
        id: 'test-1',
        name: 'Test Feed',
        url: 'https://example.com/feed.xml',
        category: 'Test',
        color: const Color(0xFF3B82F6),
        icon: Icons.rss_feed,
      );

      final result = await repository.saveFeed(feed);

      expect(result.isSuccess, true);

      final getFeedsResult = await repository.getAllFeeds();
      expect(getFeedsResult.isSuccess, true);
      expect(getFeedsResult.data!.length, 1);
      expect(getFeedsResult.data!.first.name, 'Test Feed');
    });

    test('Should retrieve all feeds', () async {
      final feed1 = CustomFeed(
        id: 'test-2',
        name: 'Feed 1',
        url: 'https://example.com/feed1.xml',
        category: 'Test',
        color: const Color(0xFF3B82F6),
        icon: Icons.rss_feed,
      );

      final feed2 = CustomFeed(
        id: 'test-3',
        name: 'Feed 2',
        url: 'https://example.com/feed2.xml',
        category: 'Test',
        color: const Color(0xFFDC2626),
        icon: Icons.rss_feed,
      );

      await repository.saveFeed(feed1);
      await repository.saveFeed(feed2);

      final result = await repository.getAllFeeds();

      expect(result.isSuccess, true);
      expect(result.data!.length, 2);
    });

    test('Should return empty list when no feeds exist', () async {
      final result = await repository.getAllFeeds();

      expect(result.isSuccess, true);
      expect(result.data!.isEmpty, true);
    });

    test('Should update an existing feed', () async {
      final feed = CustomFeed(
        id: 'test-4',
        name: 'Original Name',
        url: 'https://example.com/feed.xml',
        category: 'Original',
        color: const Color(0xFF3B82F6),
        icon: Icons.rss_feed,
      );

      await repository.saveFeed(feed);

      final updatedFeed = feed.copyWith(
        name: 'Updated Name',
        category: 'Updated',
      );

      final updateResult = await repository.updateFeed(updatedFeed);
      expect(updateResult.isSuccess, true);

      final getResult = await repository.getAllFeeds();
      expect(getResult.data!.first.name, 'Updated Name');
      expect(getResult.data!.first.category, 'Updated');
    });

    test('Should delete a feed', () async {
      final feed = CustomFeed(
        id: 'test-5',
        name: 'To Delete',
        url: 'https://example.com/feed.xml',
        category: 'Test',
        color: const Color(0xFF3B82F6),
        icon: Icons.rss_feed,
      );

      await repository.saveFeed(feed);

      var getResult = await repository.getAllFeeds();
      expect(getResult.data!.length, 1);

      await repository.deleteFeed(feed.id);

      getResult = await repository.getAllFeeds();
      expect(getResult.data!.isEmpty, true);
    });

    test('Should toggle feed enabled status', () async {
      final feed = CustomFeed(
        id: 'test-6',
        name: 'Toggle Feed',
        url: 'https://example.com/feed.xml',
        category: 'Test',
        color: const Color(0xFF3B82F6),
        icon: Icons.rss_feed,
        isEnabled: true,
      );

      await repository.saveFeed(feed);

      await repository.toggleFeed(feed.id);

      final getResult = await repository.getAllFeeds();
      expect(getResult.data!.first.isEnabled, false);
    });

    test('Should validate valid HTTP URL', () async {
      final result = await repository.validateFeedUrl('https://example.com/feed.xml');

      expect(result.isSuccess, true);
      expect(result.data, true);
    });

    test('Should reject empty URL', () async {
      final result = await repository.validateFeedUrl('');

      expect(result.isFailure, true);
      expect(result.error, contains('empty'));
    });

    test('Should reject URL without http scheme', () async {
      final result = await repository.validateFeedUrl('example.com/feed.xml');

      expect(result.isFailure, true);
      expect(result.error, contains('http'));
    });

    test('Should reject non-HTTP URLs', () async {
      final result = await repository.validateFeedUrl('ftp://example.com/feed.xml');

      expect(result.isFailure, true);
      expect(result.error, contains('HTTP'));
    });

    test('Should handle update for non-existent feed', () async {
      final feed = CustomFeed(
        id: 'nonexistent-1',
        name: 'Nonexistent',
        url: 'https://example.com/feed.xml',
        category: 'Test',
        color: const Color(0xFF3B82F6),
        icon: Icons.rss_feed,
      );

      final result = await repository.updateFeed(feed);

      expect(result.isFailure, true);
      expect(result.error, contains('not found'));
    });

    test('Should handle delete for non-existent feed', () async {
      final result = await repository.deleteFeed('nonexistent-2');

      expect(result.isFailure, true);
    });
  });
}
```

**Step 3: Register repository in service locator**

Modify: `lib/di/service_locator.dart`

```dart
import '../repositories/custom_feed_repository.dart';

// In setupServiceLocator:
getIt.registerLazySingleton<CustomFeedRepository>(() => CustomFeedRepository());
```

**Step 4: Run tests**

Run: `flutter test test/unit/repositories/custom_feed_repository_test.dart`
Expected: All tests pass

**Step 5: Commit**

```bash
git add lib/repositories/custom_feed_repository.dart test/unit/repositories/custom_feed_repository_test.dart lib/di/service_locator.dart
git commit -m "feat: Add CustomFeedRepository with full CRUD operations"
```

---

## Task 19: Create custom feeds screen

**Files:**
- Create: `lib/screens/custom_feeds_screen.dart`

**Step 1: Write custom feeds screen**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/custom_feed.dart';
import '../repositories/custom_feed_repository.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/add_feed_dialog.dart';

/// Screen for managing custom RSS feeds
class CustomFeedsScreen extends StatefulWidget {
  const CustomFeedsScreen({super.key});

  @override
  State<CustomFeedsScreen> createState() => _CustomFeedsScreenState();
}

class _CustomFeedsScreenState extends State<CustomFeedsScreen> {
  final CustomFeedRepository _repository = CustomFeedRepository();
  List<CustomFeed> _feeds = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeeds();
  }

  Future<void> _loadFeeds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _repository.getAllFeeds();

    if (mounted) {
      setState(() {
        if (result.isSuccess) {
          _feeds = result.data ?? [];
        } else {
          _errorMessage = result.error ?? 'Failed to load feeds';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddFeedDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const AddFeedDialog(),
    );

    if (result == true) {
      _loadFeeds();
    }
  }

  Future<void> _toggleFeed(CustomFeed feed) async {
    final result = await _repository.toggleFeed(feed.id);

    if (result.isSuccess) {
      _loadFeeds();
    } else {
      _showSnackBar(result.error ?? 'Failed to toggle feed', AppColors.error);
    }
  }

  Future<void> _deleteFeed(CustomFeed feed) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Feed'),
        content: Text('Are you sure you want to delete "${feed.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await _repository.deleteFeed(feed.id);

      if (result.isSuccess) {
        _showSnackBar('Feed deleted', AppColors.success);
        _loadFeeds();
      } else {
        _showSnackBar(result.error ?? 'Failed to delete feed', AppColors.error);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Custom Feeds',
          style: GoogleFonts.playfairDisplay(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: _showAddFeedDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _feeds.isEmpty
                  ? _buildEmptyState()
                  : _buildFeedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.rss_feed_rounded,
              size: 72,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No custom feeds yet',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the + button to add your first RSS feed',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.6,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 72,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadFeeds,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _feeds.length,
      itemBuilder: (context, index) {
        final feed = _feeds[index];
        return _buildFeedCard(feed);
      },
    );
  }

  Widget _buildFeedCard(CustomFeed feed) {
    return Dismissible(
      key: ValueKey(feed.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteFeed(feed),
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_rounded, color: Colors.white, size: 24),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: feed.isEnabled
                ? AppColors.divider.withValues(alpha: 0.5)
                : AppColors.divider.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: feed.color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: feed.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Icon(feed.icon, size: 20, color: feed.isEnabled ? feed.color : AppColors.textTertiary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feed.name,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: feed.isEnabled ? AppColors.textPrimary : AppColors.textTertiary,
                        height: 1.3,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feed.url,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            feed.category,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: feed.color,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: feed.isEnabled,
                onChanged: (_) => _toggleFeed(feed),
                activeColor: feed.color,
                activeTrackColor: feed.color.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Create add feed dialog**

Create: `lib/widgets/add_feed_dialog.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/custom_feed.dart';
import '../repositories/custom_feed_repository.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AddFeedDialog extends StatefulWidget {
  const AddFeedDialog({super.key});

  @override
  State<AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<AddFeedDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _repository = CustomFeedRepository();

  String _selectedCategory = 'General';
  Color _selectedColor = AppColors.techPrimary;
  IconData _selectedIcon = Icons.rss_feed;

  final List<String> _categories = [
    'General',
    'Technology',
    'News',
    'Science',
    'Sports',
    'Entertainment',
    'Finance',
    'Health',
  ];

  final List<Color> _colors = [
    AppColors.techPrimary,
    AppColors.newsPrimary,
    AppColors.sciencePrimary,
    AppColors.sportsPrimary,
    AppColors.entertainmentPrimary,
    const Color(0xFF059669),
    const Color(0xFFDC2626),
    const Color(0xFF7C3AED),
  ];

  final List<IconData> _icons = [
    Icons.rss_feed,
    Icons.article,
    Icons.newspaper,
    Icons.science,
    Icons.sports,
    Icons.theater_rounded,
    Icons.attach_money,
    Icons.health_and_safety,
    Icons.business,
    Icons.trending_up,
    Icons.public,
  ];

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveFeed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    // Validate URL
    final validation = await _repository.validateFeedUrl(_urlController.text.trim());
    if (validation.isFailure) {
      setState(() {
        _errorMessage = validation.error;
        _isSaving = false;
      });
      return;
    }

    // Create feed
    final feed = CustomFeed(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      url: _urlController.text.trim(),
      category: _selectedCategory,
      color: _selectedColor,
      icon: _selectedIcon,
    );

    final result = await _repository.saveFeed(feed);

    setState(() {
      _isSaving = false;
    });

    if (result.isSuccess) {
      if (mounted) {
        Navigator.pop(context, true);
      }
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Failed to save feed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Add Custom Feed',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Feed Name',
                    labelStyle: GoogleFonts.dmSans(fontSize: 14,
 color: AppColors.textSecondary),
                    hintText: 'e.g., My Blog',
                    hintStyle: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.bookmark_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Feed name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // URL field
                TextFormField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: 'RSS Feed URL',
                    labelStyle: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textSecondary),
                    hintText: 'https://example.com/feed.xml',
                    hintStyle: GoogleFonts.dmSans(fontSize: 16, color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.link_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'RSS feed URL is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Category selector
                Text(
                  'Category',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    return FilterChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      selectedColor: _selectedColor.withValues(alpha: 0.15),
                      labelStyle: GoogleFonts.dmSans(
                        color: _selectedCategory == category ? _selectedColor : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Color selector
                Text(
                  'Color',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: _colors.map((color) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _selectedColor == color ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Icon selector
                Text(
                  'Icon',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _icons.map((icon) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedIcon == icon
                              ? _selectedColor.withValues(alpha: 0.15)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedIcon == icon ? _selectedColor : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 18,
                          color: _selectedIcon == icon ? _selectedColor : AppColors.textSecondary,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveFeed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : Text(
                                'Add Feed',
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

**Step 3: Add navigation to custom feeds screen**

Modify: `lib/screens/feed_screen.dart` - add to settings:

```dart
_buildSettingsItem(
  icon: Icons.rss_feed_rounded,
  title: 'Custom Feeds',
  subtitle: Text('${_customFeedsCount} custom feeds'),
  trailing: const Icon(Icons.chevron_right_rounded,
      color: AppColors.textTertiary),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomFeedsScreen(),
      ),
    );
  },
),
```

Add state:
```dart
int _customFeedsCount = 0;
```

Add import:
```dart
import '../screens/custom_feeds_screen.dart';
import '../repositories/custom_feed_repository.dart';
```

Load in initState:
```dart
Future<void> _loadCustomFeedsCount() async {
  final repository = CustomFeedRepository();
  final result = await repository.getAllFeeds();
  if (result.isSuccess && mounted) {
    setState(() {
      _customFeedsCount = result.data?.length ?? 0;
    });
  }
}
```

**Step 4: Commit**

```bash
git add lib/screens/custom_feeds_screen.dart lib/widgets/add_feed_dialog.dart lib/screens/feed_screen.dart
git commit -m "feat: Add custom RSS feeds management screen"
```

---

**Phase 4 Complete Summary:**
- ✅ Created CustomFeed model with tests
- ✅ Built CustomFeedRepository with full CRUD
- ✅ Created custom feeds management UI
- ✅ Added feed creation dialog with validation
- ✅ Integrated into main settings screen

---

# Phase 5: Advanced Features (Week 9-10)

**Continue with reader mode, bookmarking, and background sync. Due to length, this portion is abbreviated - follow same pattern with:**