import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/widgets/bento_saved_articles.dart';
import 'package:flutter_test/flutter_test.dart';

Article _a(String id, DateTime pubDate) => Article(
  id: id,
  title: 't-$id',
  description: '',
  fullContent: '',
  link: 'https://e.com/$id',
  sourceId: 'verge',
  sourceName: 'The Verge',
  pubDate: pubDate,
);

void main() {
  // Regression: the prior _groupByRecency had a dead "this week" branch
  // that folded every older-than-yesterday article into one bucket and
  // could never emit a true "Earlier" group. Now Today/Yesterday/Earlier
  // each receive exactly the articles in their day-window.
  final now = DateTime(2026, 8, 17, 14, 0); // a Monday
  final today = DateTime(now.year, now.month, now.day);

  test('articles older than yesterday land in Earlier, not conflated', () {
    final out = groupSavedByRecency(
      [
        _a('a', today.add(const Duration(hours: 2))),
        _a('b', today.subtract(const Duration(days: 1)).add(const Duration(hours: 5))),
        _a('c', today.subtract(const Duration(days: 5))),
        _a('d', today.subtract(const Duration(days: 40))),
      ],
      now: now,
    );

    expect(out.map((g) => g.label).toList(), [
      'Saved today',
      'Yesterday',
      'Earlier',
    ]);
    final earlier = out.lastWhere((g) => g.label == 'Earlier').items;
    expect(earlier.map((a) => a.id).toList(), ['c', 'd']);
  });

  test('empty buckets are omitted and order is Today → Yesterday → Earlier', () {
    final out = groupSavedByRecency(
      [_a('old', today.subtract(const Duration(days: 10)))],
      now: now,
    );

    expect(out.length, 1);
    expect(out.single.label, 'Earlier');
  });

  test('within-group sort is newest first', () {
    final out = groupSavedByRecency(
      [
        _a('old', today.subtract(const Duration(days: 40))),
        _a('newer', today.subtract(const Duration(days: 5))),
      ],
      now: now,
    );

    expect(out.single.label, 'Earlier');
    expect(out.single.items.map((a) => a.id).toList(), ['newer', 'old']);
  });
}
