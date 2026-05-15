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
        pubDate: DateTime.fromMillisecondsSinceEpoch(1705314600000),
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
      expect(json['pubDate'], 1705314600000); // milliseconds since epoch for UTC
      expect(json['author'], 'Test Author');
      expect(json['imageUrl'], 'https://example.com/image.jpg');
      expect(json['isRead'], false);
      expect(json['isSaved'], false);
      expect(json['fetchedFullContent'], isNull); // testArticle doesn't set it
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
