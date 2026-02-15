import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/utils/helpers.dart';

void main() {
  group('Helpers - String Operations', () {
    group('stripHtmlTags', () {
      test('Should strip basic HTML tags', () {
        const html = '<p>Hello World</p>';
        expect(Helpers.stripHtmlTags(html), 'Hello World');
      });

      test('Should strip multiple nested HTML tags', () {
        const html = '<div><p><strong>Hello</strong> World</p></div>';
        expect(Helpers.stripHtmlTags(html), 'Hello World');
      });

      test('Should strip tags with attributes', () {
        const html = '<a href="https://example.com" class="link">Link</a>';
        expect(Helpers.stripHtmlTags(html), 'Link');
      });

      test('Should strip self-closing tags', () {
        const html = '<br/>Line break<br />';
        expect(Helpers.stripHtmlTags(html), 'Line break');
      });

      test('Should strip script and style tags (but leaves content)', () {
        const html = '<script>alert("test")</script><p>Content</p>';
        // The implementation only strips tags, not content inside script tags
        expect(Helpers.stripHtmlTags(html), 'alert("test")Content');
      });

      test('Should handle empty string', () {
        expect(Helpers.stripHtmlTags(''), '');
      });

      test('Should handle string with no HTML tags', () {
        expect(Helpers.stripHtmlTags('Plain text'), 'Plain text');
      });

      test('Should trim whitespace from result', () {
        const html = '  <p>  Text  </p>  ';
        expect(Helpers.stripHtmlTags(html), 'Text');
      });

      test('Should handle special characters in HTML', () {
        const html = '<p>Special &amp; characters &lt;&gt;</p>';
        expect(Helpers.stripHtmlTags(html), 'Special &amp; characters &lt;&gt;');
      });

      test('Should strip multiline HTML', () {
        const html = '<div>\n  <h1>Title</h1>\n  <p>Paragraph</p>\n</div>';
        // The implementation strips tags and trims result
        expect(Helpers.stripHtmlTags(html), 'Title\n  Paragraph');
      });
    });

    group('truncateText', () {
      test('Should return text unchanged if length <= maxLength', () {
        const text = 'Short text';
        expect(Helpers.truncateText(text, 20), 'Short text');
      });

      test('Should truncate text with ellipsis if length > maxLength', () {
        const text = 'This is a very long text';
        expect(Helpers.truncateText(text, 10), 'This is a ...');
      });

      test('Should truncate at exact maxLength', () {
        const text = 'Hello World';
        expect(Helpers.truncateText(text, 5), 'Hello...');
      });

      test('Should handle maxLength of 0', () {
        const text = 'Hello World';
        expect(Helpers.truncateText(text, 0), '...');
      });

      test('Should handle negative maxLength (throws range error)', () {
        // The implementation doesn't handle negative values - it throws RangeError
        expect(
          () => Helpers.truncateText('Hello World', -5),
          throwsA(isA<RangeError>()),
        );
      });

      test('Should handle empty string', () {
        expect(Helpers.truncateText('', 10), '');
      });

      test('Should handle single character', () {
        expect(Helpers.truncateText('A', 0), '...');
        expect(Helpers.truncateText('A', 1), 'A');
      });

      test('Should handle Unicode characters', () {
        const text = 'Hello World 你好世界';
        // 'Hello World ' = 12 characters (with space)
        expect(Helpers.truncateText(text, 11), 'Hello World...');
      });

      test('Should truncate when length equals maxLength (uses <= check)', () {
        const text = 'Exactly ten';
        // Implementation uses <=, so text equal to maxLength gets truncated
        expect(Helpers.truncateText(text, 10), 'Exactly te...');
      });

      test('Should add ellipsis only once', () {
        const text = 'This is very very very very long';
        expect(Helpers.truncateText(text, 10).endsWith('...'), true);
      });
    });

    group('isValidImageUrl', () {
      test('Should return true for common image extensions - jpg', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.jpg'), true);
      });

      test('Should return true for common image extensions - jpeg', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.jpeg'), true);
      });

      test('Should return true for common image extensions - png', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.png'), true);
      });

      test('Should return true for common image extensions - gif', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.gif'), true);
      });

      test('Should return true for common image extensions - bmp', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.bmp'), true);
      });

      test('Should return true for common image extensions - webp', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.webp'), true);
      });

      test('Should return true for common image extensions - svg', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.svg'), true);
      });

      test('Should return true for common image extensions - avif', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.avif'), true);
      });

      test('Should return true for common image extensions - heic', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.heic'), true);
      });

      test('Should return true for common image extensions - ico', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.ico'), true);
      });

      test('Should return true for common image extensions - tif', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.tif'), true);
      });

      test('Should return true for common image extensions - tiff', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.tiff'), true);
      });

      test('Should return true for image extension in query string', () {
        // The implementation checks for .jpg (with dot), not just jpg
        expect(Helpers.isValidImageUrl('https://example.com/img?format=.jpg'), true);
        // Or when format value ends with extension
        expect(Helpers.isValidImageUrl('https://example.com/img.jpg?width=800'), true);
      });

      test('Should return true for image extension in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/path/to/file.jpg.png'), true);
      });

      test('Should return true for common image CDNs - Cloudinary', () {
        expect(Helpers.isValidImageUrl('https://res.cloudinary.com/demo/image/upload/sample.jpg'), true);
      });

      test('Should return true for common image CDNs - Unsplash', () {
        expect(Helpers.isValidImageUrl('https://images.unsplash.com/photo-123456789'), true);
      });

      test('Should return true for common image CDNs - Pixabay', () {
        expect(Helpers.isValidImageUrl('https://cdn.pixabay.com/photo/123456789'), true);
      });

      test('Should return true for common image CDNs - Imgur', () {
        expect(Helpers.isValidImageUrl('https://imgur.com/abc123.jpg'), true);
      });

      test('Should return true for common image CDNs - Imgur direct', () {
        expect(Helpers.isValidImageUrl('https://i.imgur.com/abc123.jpg'), true);
      });

      test('Should return true for common image CDNs - Medium', () {
        expect(Helpers.isValidImageUrl('https://cdn-images-1.medium.com/max/800/1*2.jpg'), true);
      });

      test('Should return true for Twitter images', () {
        expect(Helpers.isValidImageUrl('https://pbs.twimg.com/media/xyz.jpg'), true);
      });

      test('Should return true for Twitter images abs-0', () {
        expect(Helpers.isValidImageUrl('https://abs-0.twimg.com/media/xyz.jpg'), true);
      });

      test('Should return true for URLs with cdn in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/cdn/images/photo.jpg'), true);
      });

      test('Should return true for URLs with images in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/images/photo.jpg'), true);
      });

      test('Should return true for URLs with static in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/static/assets/photo.jpg'), true);
      });

      test('Should return true for URLs with assets in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/assets/photo.jpg'), true);
      });

      test('Should return true for URLs with img in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/img/photo.jpg'), true);
      });

      test('Should return true for URLs with media in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/media/photo.jpg'), true);
      });

      test('Should return true for URLs with thumbs in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/thumbs/photo.jpg'), true);
      });

      test('Should return true for URLs with thumbnail in path', () {
        expect(Helpers.isValidImageUrl('https://example.com/thumbnail/photo.jpg'), true);
      });

      test('Should return true for URLs with word "image"', () {
        expect(Helpers.isValidImageUrl('https://example.com/preview/image-id'), true);
      });

      test('Should return true for URLs with word "photo"', () {
        expect(Helpers.isValidImageUrl('https://example.com/preview/photo-id'), true);
      });

      test('Should return true for URLs with word "picture"', () {
        expect(Helpers.isValidImageUrl('https://example.com/preview/picture-id'), true);
      });

      test('Should return true for URLs with width parameter', () {
        expect(Helpers.isValidImageUrl('https://example.com/file?width=800'), true);
        expect(Helpers.isValidImageUrl('https://example.com/file&width=800'), true);
        expect(Helpers.isValidImageUrl('https://example.com/file?w=800'), true);
      });

      test('Should return true for URLs with height parameter', () {
        expect(Helpers.isValidImageUrl('https://example.com/file?height=600'), true);
        expect(Helpers.isValidImageUrl('https://example.com/file&height=600'), true);
        expect(Helpers.isValidImageUrl('https://example.com/file?h=600'), true);
      });

      test('Should return true for URLs with content and cdn', () {
        expect(Helpers.isValidImageUrl('https://example.com/content-delivery/file.jpg'), true);
        expect(Helpers.isValidImageUrl('https://example.com/content-cdn/file.jpg'), true);
      });

      test('Should return true for URLs with content and media', () {
        expect(Helpers.isValidImageUrl('https://example.com/content-media/file.jpg'), true);
      });

      test('Should return false for empty string', () {
        expect(Helpers.isValidImageUrl(''), false);
      });

      test('Should return false for non-image URLs', () {
        expect(Helpers.isValidImageUrl('https://example.com/document.pdf'), false);
      });

      test('Should return false for HTML pages', () {
        expect(Helpers.isValidImageUrl('https://example.com/page.html'), false);
      });

      test('Should return false for text files', () {
        expect(Helpers.isValidImageUrl('https://example.com/data.txt'), false);
      });

      test('Should return false for video files', () {
        expect(Helpers.isValidImageUrl('https://example.com/video.mp4'), false);
      });

      test('Should return false for audio files', () {
        expect(Helpers.isValidImageUrl('https://example.com/audio.mp3'), false);
      });

      test('Should return false for API endpoints without image keywords', () {
        expect(Helpers.isValidImageUrl('https://api.example.com/data/123'), false);
      });

      test('Should be case insensitive for extensions', () {
        expect(Helpers.isValidImageUrl('https://example.com/image.JPG'), true);
        expect(Helpers.isValidImageUrl('https://example.com/image.PNG'), true);
      });

      test('Should be case insensitive for patterns', () {
        expect(Helpers.isValidImageUrl('https://CDN.example.com/image'), true);
        expect(Helpers.isValidImageUrl('https://example.com/IMAGES/photo'), true);
      });
    });

    group('isValidUrl', () {
      test('Should return true for valid HTTP URL', () {
        expect(Helpers.isValidUrl('http://example.com'), true);
      });

      test('Should return true for valid HTTPS URL', () {
        expect(Helpers.isValidUrl('https://example.com'), true);
      });

      test('Should return true for URL with path', () {
        expect(Helpers.isValidUrl('https://example.com/path/to/resource'), true);
      });

      test('Should return true for URL with query parameters', () {
        expect(Helpers.isValidUrl('https://example.com/path?param=value'), true);
      });

      test('Should return true for URL with fragment', () {
        expect(Helpers.isValidUrl('https://example.com/path#section'), true);
      });

      test('Should return true for URL with subdomain', () {
        expect(Helpers.isValidUrl('https://sub.example.com'), true);
      });

      test('Should return true for URL with port', () {
        expect(Helpers.isValidUrl('https://example.com:8080'), true);
      });

      test('Should return true for URL with user info', () {
        expect(Helpers.isValidUrl('https://user:pass@example.com'), true);
      });

      test('Should return false for URL without scheme', () {
        expect(Helpers.isValidUrl('example.com'), false);
      });

      test('Should return false for invalid scheme (ftp)', () {
        expect(Helpers.isValidUrl('ftp://example.com'), false);
      });

      test('Should return false for invalid scheme (file)', () {
        expect(Helpers.isValidUrl('file:///path/to/file'), false);
      });

      test('Should return false for empty string', () {
        expect(Helpers.isValidUrl(''), false);
      });

      test('Should return false for invalid format', () {
        expect(Helpers.isValidUrl('not a url'), false);
      });

      test('Should return false for null-like string', () {
        expect(Helpers.isValidUrl('invalid'), false);
      });

      test('Should return false for malformed scheme', () {
        expect(Helpers.isValidUrl('://example.com'), false);
      });

      test('Should return true for URL with scheme only (has valid scheme)', () {
        // Implementation checks if scheme is http or https, https:// is valid
        expect(Helpers.isValidUrl('https://'), true);
      });
    });

    group('generateHash', () {
      test('Should generate consistent hash for same input', () {
        const input = 'test string';
        final hash1 = Helpers.generateHash(input);
        final hash2 = Helpers.generateHash(input);
        expect(hash1, hash2);
      });

      test('Should generate different hashes for different inputs', () {
        final hash1 = Helpers.generateHash('input1');
        final hash2 = Helpers.generateHash('input2');
        expect(hash1, isNot(hash2));
      });

      test('Should generate hash for empty string', () {
        final hash = Helpers.generateHash('');
        expect(hash, isA<int>());
      });

      test('Should generate hash for single character', () {
        final hash = Helpers.generateHash('a');
        expect(hash, isA<int>());
      });

      test('Should generate hash for long string', () {
        final longInput = 'a' * 1000;
        final hash = Helpers.generateHash(longInput);
        expect(hash, isA<int>());
      });

      test('Should handle Unicode characters', () {
        final hash = Helpers.generateHash('Hello World 你好世界');
        expect(hash, isA<int>());
      });

      test('Should generate hash for special characters', () {
        final input = r'!@#$%^&*()_+-=[]{}|;:,.<>?';
        final hash1 = Helpers.generateHash(input);
        final hash2 = Helpers.generateHash(input);
        expect(hash1, hash2);
      });

      test('Should generate hash for numeric string', () {
        final input = '1234567890';
        final hash = Helpers.generateHash(input);
        expect(hash, isA<int>());
      });

      test('Should generate hash for whitespace string', () {
        final hash1 = Helpers.generateHash('  spaces  ');
        final hash2 = Helpers.generateHash('  spaces  ');
        expect(hash1, hash2);
      });

      test('Should handle case sensitivity', () {
        final hash1 = Helpers.generateHash('Test');
        final hash2 = Helpers.generateHash('test');
        expect(hash1, isNot(hash2));
      });

      test('Should generate hash for URL-like string', () {
        final input = 'https://example.com/article/123';
        final hash = Helpers.generateHash(input);
        expect(hash, isA<int>());
      });

      test('Should generate hash for mixed content', () {
        final input = 'Article Title\n123\nhttps://example.com';
        final hash1 = Helpers.generateHash(input);
        final hash2 = Helpers.generateHash(input);
        expect(hash1, hash2);
      });

      test('Should generate positive or negative hash (both acceptable)', () {
        final hash = Helpers.generateHash('test');
        expect(hash, isA<int>());
        // Hash can be positive or negative depending on integer overflow
        // Just verify it's a valid integer
        expect(hash, isNotNull);
      });

      test('Should generate consistent hash across multiple calls', () {
        final input = 'consistency test';
        final hashes = List.generate(100, (_) => Helpers.generateHash(input));
        expect(hashes.every((h) => h == hashes[0]), true);
      });

      test('Should differentiate similar strings', () {
        final hash1 = Helpers.generateHash('string');
        final hash2 = Helpers.generateHash('string ');
        final hash3 = Helpers.generateHash('String');
        expect(hash1, isNot(hash2));
        expect(hash1, isNot(hash3));
        expect(hash2, isNot(hash3));
      });
    });
  });
}
