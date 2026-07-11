/// Continuous Feed List — the "Continuous" view-mode of the feed.
///
/// Renders articles grouped into time sections:
///
///   TODAY · 14 articles
///   YESTERDAY · 6 articles
///   EARLIER · 27 articles
///
/// Each section uses different vertical density to encode recency —
/// Today breathes, Yesterday is moderate, Earlier is compact.
library;

import 'package:flutter/material.dart';
import '../models/article.dart';
import '../utils/design_tokens.dart';
import '../widgets/list_article_card.dart';
import '../widgets/section_eyebrow.dart';

class ContinuousFeedList extends StatelessWidget {
  final List<Article> articles;
  final void Function(int index) onTap;
  final double measure;

  const ContinuousFeedList({
    super.key,
    required this.articles,
    required this.onTap,
    this.measure = 720,
  });

  @override
  Widget build(BuildContext context) {
    final groups = _groupByRecency(articles);

    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> items = [];
    for (final g in groups) {
      items.add(SectionEyebrow(
        label: g.label,
        count: g.items.length,
        density: g.density,
      ));
      for (var i = 0; i < g.items.length; i++) {
        // Look up global index for tap-callback.
        final globalIndex = articles.indexOf(g.items[i]);
        items.add(ListArticleCard(
          article: g.items[i],
          index: globalIndex,
          measure: measure,
          onTap: () => onTap(globalIndex),
        ));
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      children: items,
    );
  }
}

class _Section {
  final String label;
  final SectionDensity density;
  final List<Article> items;
  _Section(this.label, this.density, this.items);
}

List<_Section> _groupByRecency(List<Article> articles) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final List<Article> todayList = [];
  final List<Article> yesterdayList = [];
  final List<Article> earlierList = [];

  for (final a in articles) {
    final dtDay = DateTime(a.pubDate.year, a.pubDate.month, a.pubDate.day);
    if (dtDay == today) {
      todayList.add(a);
    } else if (dtDay == yesterday) {
      yesterdayList.add(a);
    } else {
      earlierList.add(a);
    }
  }

  // Sort newest first within each group.
  todayList.sort((a, b) => b.pubDate.compareTo(a.pubDate));
  yesterdayList.sort((a, b) => b.pubDate.compareTo(a.pubDate));
  earlierList.sort((a, b) => b.pubDate.compareTo(a.pubDate));

  return [
    if (todayList.isNotEmpty)
      _Section('Today', SectionDensity.relaxed, todayList),
    if (yesterdayList.isNotEmpty)
      _Section('Yesterday', SectionDensity.moderate, yesterdayList),
    if (earlierList.isNotEmpty)
      _Section('Earlier', SectionDensity.compact, earlierList),
  ];
}
