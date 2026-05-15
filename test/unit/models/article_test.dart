import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/article.dart';

void main() {
  group('Article Model Compound ID', () {
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
        pubDate: DateTime.fromMillisecondsSinceEpoch(1705314600000),
        author: 'Test Author',
        imageUrl: 'https://example.com/image.jpg',
        isRead: false,
        isSaved: false,
      );
    });

    // ============================================================
    // Static methods: makeId, extractSourceId, extractOriginalId
    // ============================================================

    group('makeId', () {
      test('creates compound ID with source and original ID', () {
        final id = Article.makeId('verge', '12345');
        expect(id, 'verge:12345');
      });

      test('handles numeric-looking original IDs as strings', () {
        final id = Article.makeId('worker', '9876543');
        expect(id, 'worker:9876543');
      });

      test('handles complex original IDs', () {
        final id = Article.makeId('source', 'https://example.com/path');
        expect(id, 'source:https://example.com/path');
      });
    });

    group('extractSourceId', () {
      test('extracts sourceId from valid compound ID', () {
        final sourceId = Article.extractSourceId('verge:12345');
        expect(sourceId, 'verge');
      });

      test('extracts from worker-format ID', () {
        final sourceId = Article.extractSourceId('worker:123');
        expect(sourceId, 'worker');
      });

      test('returns null for simple ID without separator', () {
        final sourceId = Article.extractSourceId('simple-id');
        expect(sourceId, isNull);
      });

      test('returns null for empty string', () {
        final sourceId = Article.extractSourceId('');
        expect(sourceId, isNull);
      });

      test('returns null for ID with multiple colons', () {
        // Multiple colons means it doesn't match the 2-part compound format
        final sourceId = Article.extractSourceId('a:b:c');
        expect(sourceId, isNull);
      });
    });

    group('extractOriginalId', () {
      test('extracts originalId from valid compound ID', () {
        final originalId = Article.extractOriginalId('verge:12345');
        expect(originalId, '12345');
      });

      test('extracts from worker-format ID', () {
        final originalId = Article.extractOriginalId('worker:9876543');
        expect(originalId, '9876543');
      });

      test('returns full ID for simple ID without separator (backwards compat)', () {
        final originalId = Article.extractOriginalId('simple-id');
        expect(originalId, 'simple-id');
      });

      test('returns full ID for empty string', () {
        final originalId = Article.extractOriginalId('');
        expect(originalId, '');
      });

      test('returns part after first colon for multiple colons', () {
        // For "a:b:c", split gives ['a', 'b', 'c'], parts.length == 3 != 2
        // So it returns the full original ID (backwards compat for non-compound IDs)
        final originalId = Article.extractOriginalId('a:b:c');
        expect(originalId, 'a:b:c');
      });
    });

    // ============================================================
    // fromJson with different rawId types
    // ============================================================

    group('fromJson with int rawId (Worker API format)', () {
      test('converts int ID to compound key with sourceId', () {
        final json = {
          'id': 123, // int from Worker API
          'sourceId': 'worker',
          'title': 'Worker Article',
          'pubDate': 1705314600000,
        };

        final article = Article.fromJson(json);

        expect(article.id, 'worker:123');
        expect(article.sourceId, 'worker');
      });

      test('handles large numeric IDs', () {
        final json = {
          'id': 9876543210, // large int
          'sourceId': 'worker',
          'title': 'Large ID Article',
          'pubDate': 1705314600000,
        };

        final article = Article.fromJson(json);

        expect(article.id, 'worker:9876543210');
      });

      test('handles negative IDs if Worker API returns them', () {
        final json = {
          'id': -1,
          'sourceId': 'worker',
          'title': 'Negative ID Article',
          'pubDate': 1705314600000,
        };

        final article = Article.fromJson(json);

        expect(article.id, 'worker:-1');
      });
    });

    group('fromJson with compound string rawId (local storage format)', () {
      test('uses existing compound key as-is', () {
        final json = {
          'id': 'verge:9876543', // already compound from local storage
          'sourceId': 'verge',
          'title': 'Stored Article',
          'pubDate': 1705314600000,
        };

        final article = Article.fromJson(json);

        expect(article.id, 'verge:9876543');
        expect(article.sourceId, 'verge');
      });

      test('preserves existing compound ID even when sourceId differs', () {
        // This can happen if article was stored before sourceId normalization
        final json = {
          'id': 'old-source:123',
          'sourceId': 'new-source',
          'title': 'Migrated Article',
          'pubDate': 1705314600000,
        };

        final article = Article.fromJson(json);

        expect(article.id, 'old-source:123');
      });
    });

    group('fromJson with string rawId without colon (RSS/unknown format)', () {
      test('converts plain string ID to compound key', () {
        final json = {
          'id': 'rss-article-456', // plain string from RSS or unknown source
          'sourceId': 'rss',
          'title': 'RSS Article',
          'pubDate': 1705314600000,
        };

        final article = Article.fromJson(json);

        expect(article.id, 'rss:rss-article-456');
        expect(article.sourceId, 'rss');
      });

      test('handles empty sourceId with string ID', () {
        final json = {
          'id': 'some-id',
          'title': 'No Source Article',
          'pubDate': 1705314600000,
        };

        final article = Article.fromJson(json);

        expect(article.id, ':some-id');
        expect(article.sourceId, '');
      });
    });

    // ============================================================
    // Existing tests preserved from original file
    // ============================================================

    test('Should create Article with correct values', () {
      expect(testArticle.id, 'test-id-1');
      expect(testArticle.title, 'Test Article Title');
      expect(testArticle.description, 'This is a test description');
      expect(testArticle.fullContent, 'Full article content here');
      expect(testArticle.link, 'https://example.com/article/1');
      expect(testArticle.sourceId, 'test-source');
      expect(testArticle.sourceName, 'Test Source');
      expect(testArticle.pubDate.millisecondsSinceEpoch, 1705314600000);
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
      expect(json['pubDate'], 1705314600000);
      expect(json['author'], 'Test Author');
      expect(json['imageUrl'], 'https://example.com/image.jpg');
      expect(json['isRead'], false);
      expect(json['isSaved'], false);
      expect(json['fetchedFullContent'], isNull);
    });

    test('Should create Article from JSON correctly', () {
      final timestamp = 1705314600000;

      final json = {
        'id': 'test-id-2',
        'title': 'Another Article',
        'description': 'Another description',
        'fullContent': 'Another content',
        'link': 'https://example.com/article/2',
        'sourceId': 'another-source',
        'sourceName': 'Another Source',
        'pubDate': timestamp,
        'author': 'Another Author',
        'imageUrl': 'https://example.com/image2.jpg',
        'isRead': true,
        'isSaved': true,
        'fetchedFullContent': 'Fetched content',
      };

      final article = Article.fromJson(json);

      expect(article.id, 'another-source:test-id-2');
      expect(article.title, 'Another Article');
      expect(article.description, 'Another description');
      expect(article.fullContent, 'Another content');
      expect(article.link, 'https://example.com/article/2');
      expect(article.sourceId, 'another-source');
      expect(article.sourceName, 'Another Source');
      expect(article.pubDate.millisecondsSinceEpoch, timestamp);
      expect(article.author, 'Another Author');
      expect(article.imageUrl, 'https://example.com/image2.jpg');
      expect(article.isRead, true);
      expect(article.isSaved, true);
      expect(article.fetchedFullContent, 'Fetched content');
    });

    test('Should use default values for missing fields in fromJson', () {
      final json = {
        'id': 'test-id-3',
        // Note: no sourceId to test default value
        'title': 'Minimal Article',
        'pubDate': 1705314600000,
      };

      final article = Article.fromJson(json);

      expect(article.id, ':test-id-3'); // sourceId defaults to '', makeId('', 'test-id-3') = ':test-id-3'
      expect(article.title, 'Minimal Article');
      expect(article.description, ''); // default
      expect(article.fullContent, ''); // default
      expect(article.link, ''); // default
      expect(article.sourceId, ''); // default
      expect(article.sourceName, 'Unknown Source'); // default
      expect(article.author, null);
      expect(article.imageUrl, null);
      expect(article.isRead, false); // default
      expect(article.isSaved, false); // default
      expect(article.fetchedFullContent, null); // default
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