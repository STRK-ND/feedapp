import 'package:curatedfeeds/models/article.dart';
import 'package:flutter_test/flutter_test.dart';

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
      expect(article.pubDate, DateTime(2024, 1, 15));
      expect(article.author, 'Test Author');
      expect(article.isRead, false);
      expect(article.isSaved, false);
    });

    test('should serialize to JSON correctly', () {
      // Arrange
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

      // Act
      final json = article.toJson();

      // Assert
      expect(json['id'], 'test-id');
      expect(json['title'], 'Test Article');
      expect(json['author'], 'Test Author');
      expect(json['imageUrl'], 'https://example.com/image.jpg');
      expect(json['isRead'], false);
      expect(json['isSaved'], false);
    });

    test('should deserialize from JSON correctly', () {
      // Arrange
      final json = {
        'id': 'test-id',
        'title': 'Test Article',
        'description': 'Test description',
        'fullContent': 'Full content',
        'link': 'https://example.com/article',
        'sourceId': 'test-source',
        'sourceName': 'Test Source',
        'pubDate': DateTime(2024, 1, 15).millisecondsSinceEpoch,
        'author': 'Test Author',
        'imageUrl': 'https://example.com/image.jpg',
        'isRead': true,
        'isSaved': false,
      };

      // Act
      final article = Article.fromJson(json);

      // Assert
      expect(article.id, 'test-id');
      expect(article.title, 'Test Article');
      expect(article.author, 'Test Author');
      expect(article.isRead, true);
      expect(article.isSaved, false);
    });

    test('should handle missing optional fields in JSON', () {
      // Arrange
      final json = {
        'id': 'test-id',
        'title': 'Test Article',
        'description': 'Test description',
        'fullContent': 'Full content',
        'link': 'https://example.com/article',
        'sourceId': 'test-source',
        'sourceName': 'Test Source',
        'pubDate': DateTime(2024, 1, 15).millisecondsSinceEpoch,
      };

      // Act
      final article = Article.fromJson(json);

      // Assert
      expect(article.author, null);
      expect(article.imageUrl, null);
      expect(article.isRead, false);  // Defaults to false
      expect(article.isSaved, false); // Defaults to false
    });

    test('should handle empty description', () {
      // Arrange
      final article = Article(
        id: 'test',
        title: 'Test',
        description: '',
        fullContent: 'Content',
        link: 'https://test.com',
        sourceId: 'test',
        sourceName: 'test',
        pubDate: DateTime.now(),
      );

      // Assert
      expect(article.description, '');
    });
  });

  group('Date formatting calculations', () {
    test('should calculate correct difference in minutes', () {
      // Arrange
      final now = DateTime.now();
      final articleDate = now.subtract(const Duration(minutes: 30));

      // Act
      final difference = now.difference(articleDate);

      // Assert
      expect(difference.inMinutes, 30);
      expect(difference.inHours, 0);
    });

    test('should calculate correct difference in hours', () {
      // Arrange
      final now = DateTime.now();
      final articleDate = now.subtract(const Duration(hours: 2, minutes: 30));

      // Act
      final difference = now.difference(articleDate);

      // Assert
      expect(difference.inHours, 2);
      expect(difference.inDays, 0);
    });

    test('should calculate correct difference in days', () {
      // Arrange
      final now = DateTime.now();
      final articleDate = now.subtract(const Duration(days: 3, hours: 5));

      // Act
      final difference = now.difference(articleDate);

      // Assert
      expect(difference.inDays, 3);
    });
  });

  group('Time formatting edge cases', () {
    test('should handle just published (0 minutes)', () {
      // Arrange
      final now = DateTime.now();
      final articleDate = now.subtract(const Duration(seconds: 30));

      // Act
      final difference = now.difference(articleDate);

      // Assert
      expect(difference.inMinutes, 0);
    });

    test('should handle article from yesterday', () {
      // Arrange
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      // Act
      final difference = now.difference(yesterday);

      // Assert
      expect(difference.inDays, 1);
      expect(difference.inHours, greaterThanOrEqualTo(23));
    });

    test('should handle article from a week ago', () {
      // Arrange
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      // Act
      final difference = now.difference(weekAgo);

      // Assert
      expect(difference.inDays, 7);
    });
  });

  group('Article sorting', () {
    test('should sort articles by date descending', () {
      // Arrange
      final now = DateTime.now();
      final articles = [
        Article(
          id: '1',
          title: 'Oldest',
          description: 'Desc',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'test',
          pubDate: now.subtract(const Duration(hours: 3)),
        ),
        Article(
          id: '2',
          title: 'Newest',
          description: 'Desc',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'test',
          pubDate: now.subtract(const Duration(minutes: 30)),
        ),
        Article(
          id: '3',
          title: 'Middle',
          description: 'Desc',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'test',
          pubDate: now.subtract(const Duration(hours: 1)),
        ),
      ];

      // Act
      articles.sort((a, b) => b.pubDate.compareTo(a.pubDate));

      // Assert
      expect(articles[0].title, 'Newest');
      expect(articles[1].title, 'Middle');
      expect(articles[2].title, 'Oldest');
    });
  });

  group('Article filtering by read status', () {
    test('should filter out read articles', () {
      // Arrange
      final articles = [
        Article(
          id: '1',
          title: 'Article 1',
          description: 'Desc',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'test',
          pubDate: DateTime.now(),
          isRead: false,
        ),
        Article(
          id: '2',
          title: 'Article 2',
          description: 'Desc',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'test',
          pubDate: DateTime.now(),
          isRead: true,
        ),
        Article(
          id: '3',
          title: 'Article 3',
          description: 'Desc',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'test',
          pubDate: DateTime.now(),
          isRead: false,
        ),
      ];

      // Act
      final unreadArticles = articles.where((a) => !a.isRead).toList();

      // Assert
      expect(unreadArticles.length, 2);
      expect(unreadArticles[0].title, 'Article 1');
      expect(unreadArticles[1].title, 'Article 3');
    });
  });

  group('Article filtering by saved status', () {
    test('should filter by saved status', () {
      // Arrange
      final articles = [
        Article(
          id: '1',
          title: 'Article 1',
          description: 'Desc',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'test',
          pubDate: DateTime.now(),
          isSaved: true,
        ),
        Article(
          id: '2',
          title: 'Article 2',
          description: 'Desc',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'test',
          pubDate: DateTime.now(),
          isSaved: false,
        ),
      ];

      // Act
      final savedArticles = articles.where((a) => a.isSaved).toList();

      // Assert
      expect(savedArticles.length, 1);
      expect(savedArticles[0].title, 'Article 1');
    });
  });

  group('Search functionality', () {
    test('should match title in search', () {
      // Arrange
      final articles = [
        Article(
          id: '1',
          title: 'Flutter Tutorial',
          description: 'Learn Flutter',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'Test Source',
          pubDate: DateTime.now(),
        ),
        Article(
          id: '2',
          title: 'React Guide',
          description: 'Learn React',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'Test Source',
          pubDate: DateTime.now(),
        ),
      ];

      // Act
      final query = 'flutter';
      final results = articles.where((a) =>
        a.title.toLowerCase().contains(query.toLowerCase())
      ).toList();

      // Assert
      expect(results.length, 1);
      expect(results[0].title, 'Flutter Tutorial');
    });

    test('should match description in search', () {
      // Arrange
      final articles = [
        Article(
          id: '1',
          title: 'Article 1',
          description: 'Learn flutter development',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'Test Source',
          pubDate: DateTime.now(),
        ),
        Article(
          id: '2',
          title: 'Article 2',
          description: 'Learn react development',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'Test Source',
          pubDate: DateTime.now(),
        ),
      ];

      // Act
      final query = 'flutter';
      final results = articles.where((a) =>
        a.description.toLowerCase().contains(query.toLowerCase())
      ).toList();

      // Assert
      expect(results.length, 1);
      expect(results[0].id, '1');
    });

    test('should match source name in search', () {
      // Arrange
      final articles = [
        Article(
          id: '1',
          title: 'Article 1',
          description: 'Description',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'tc',
          sourceName: 'TechCrunch',
          pubDate: DateTime.now(),
        ),
        Article(
          id: '2',
          title: 'Article 2',
          description: 'Description',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'bbc',
          sourceName: 'BBC World',
          pubDate: DateTime.now(),
        ),
      ];

      // Act
      final query = 'techcrunch';
      final results = articles.where((a) =>
        a.sourceName.toLowerCase().contains(query.toLowerCase())
      ).toList();

      // Assert
      expect(results.length, 1);
      expect(results[0].sourceName, 'TechCrunch');
    });

    test('should handle empty search query', () {
      // Arrange
      final articles = [
        Article(
          id: '1',
          title: 'Article 1',
          description: 'Description',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'Test',
          pubDate: DateTime.now(),
        ),
      ];

      // Act
      final query = '';
      final results = articles.where((a) =>
        a.title.toLowerCase().contains(query.toLowerCase())
      ).toList();

      // Assert - Empty query should match all
      expect(results.length, articles.length);
    });

    test('should be case insensitive', () {
      // Arrange
      final articles = [
        Article(
          id: '1',
          title: 'FLUTTER Tutorial',
          description: 'Description',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'Test',
          pubDate: DateTime.now(),
        ),
      ];

      // Act
      final query = 'flutter';
      final results = articles.where((a) =>
        a.title.toLowerCase().contains(query.toLowerCase())
      ).toList();

      // Assert
      expect(results.length, 1);
    });

    test('should return no results for non-matching query', () {
      // Arrange
      final articles = [
        Article(
          id: '1',
          title: 'Flutter Tutorial',
          description: 'Learn Flutter',
          fullContent: 'Content',
          link: 'https://test.com',
          sourceId: 'test',
          sourceName: 'Test',
          pubDate: DateTime.now(),
        ),
      ];

      // Act
      final query = 'python';
      final results = articles.where((a) =>
        a.title.toLowerCase().contains(query.toLowerCase())
      ).toList();

      // Assert
      expect(results.length, 0);
    });
  });
}
