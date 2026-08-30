import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/services/tts_service.dart';

void main() {
  group('TtsService.chunkText', () {
    test('returns empty list for blank input', () {
      expect(TtsService.chunkText(''), isEmpty);
      expect(TtsService.chunkText('   \n\t '), isEmpty);
    });

    test('short text stays a single untouched chunk', () {
      final chunks = TtsService.chunkText('One short sentence.');
      expect(chunks, ['One short sentence.']);
    });

    test('whitespace is collapsed', () {
      final chunks = TtsService.chunkText('Hello\n\n  world \t again.');
      expect(chunks, ['Hello world again.']);
    });

    test('long text splits at sentence boundaries', () {
      const sentence = 'The quick brown fox jumps over the lazy dog. ';
      final text = sentence * 100; // ~4600 chars
      final chunks = TtsService.chunkText(text, maxChars: 2800);

      expect(chunks.length, 2);
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(2810));
        // Every chunk except possibly the last ends with a period.
      }
      expect(chunks.first.endsWith('.'), isTrue);
      // No content lost.
      final joined = chunks.join(' ').replaceAll(' ', '');
      expect(joined.length, text.replaceAll(RegExp(r'\s'), '').length);
    });

    test('falls back to comma, then space, when no sentence end fits', () {
      const clause = 'a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p. ';
      final text = clause * 60;
      final chunks = TtsService.chunkText(text, maxChars: 500);
      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(510));
        expect(c.isNotEmpty, isTrue);
      }
    });

    test('hard-cuts pathological input with no separators at all', () {
      final text = 'x' * 7000;
      final chunks = TtsService.chunkText(text, maxChars: 2800);
      expect(chunks.length, 3);
      expect(chunks.join().length, 7000);
    });
  });
}
