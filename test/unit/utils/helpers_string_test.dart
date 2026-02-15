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
        final hash = Helpers.generateHash(r'test!@#$%^&*()');
        expect(hash, isA<int>());
      });
    });
  });
}
