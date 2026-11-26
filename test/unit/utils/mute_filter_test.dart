import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/utils/mute_filter.dart';

void main() {
  group('normalizeMutedTerms', () {
    test('trims, lowercases and drops empties', () {
      expect(
        normalizeMutedTerms(['  Crypto ', 'NFTS', '', '   ']),
        equals(['crypto', 'nfts']),
      );
    });

    test('dedupes case-insensitively, first occurrence wins', () {
      expect(
        normalizeMutedTerms(['Crypto', 'CRYPTO', ' crypto ']),
        equals(['crypto']),
      );
    });

    test('clips terms to 64 chars', () {
      final long = 'x' * 100;
      final out = normalizeMutedTerms([long]);
      expect(out, hasLength(1));
      expect(out.first.length, maxMutedTermLength);
    });

    test('caps the list at 50 terms', () {
      final out = normalizeMutedTerms(List.generate(60, (i) => 'term$i'));
      expect(out, hasLength(maxMutedTerms));
      expect(out.last, equals('term49'));
    });

    test('empty input stays empty', () {
      expect(normalizeMutedTerms(const []), isEmpty);
    });

    test('commas inside an entry split into separate terms', () {
      // The worker receives the list as a comma-joined `mute=` param, so a
      // term can never contain a comma — normalization splits it first.
      expect(
        normalizeMutedTerms(['crypto, nfts', 'gaming']),
        equals(['crypto', 'nfts', 'gaming']),
      );
    });
  });

  group('articleMatchesMutedTerms', () {
    late Article article;

    setUp(() {
      article = Article(
        id: 'a1',
        title: 'Quantum Computing Advances',
        description: 'Qubits all the way down',
        fullContent: '',
        link: 'https://example.com/1',
        sourceId: 'verge',
        sourceName: 'The Verge',
        pubDate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('empty term list never matches', () {
      expect(articleMatchesMutedTerms(article, const []), isFalse);
    });

    test('matches title case-insensitively', () {
      expect(articleMatchesMutedTerms(article, ['quantum']), isTrue);
      // Contract: terms are expected already normalized (lowercase) — the
      // matcher lowercases the article text, not the terms.
      expect(articleMatchesMutedTerms(article, ['QUANTUM']), isFalse);
    });

    test('matches description case-insensitively', () {
      expect(articleMatchesMutedTerms(article, ['qubits']), isTrue);
    });

    test(
      'partial substring counts',
      () => expect(articleMatchesMutedTerms(article, ['puting']), isTrue),
    );

    test('no match on unrelated terms', () {
      expect(articleMatchesMutedTerms(article, ['football']), isFalse);
    });

    test('matches when any term matches (OR)', () {
      expect(articleMatchesMutedTerms(article, ['football', 'qubits']), isTrue);
    });

    test('blank terms are skipped', () {
      expect(articleMatchesMutedTerms(article, ['', '  ']), isFalse);
    });
  });
}
