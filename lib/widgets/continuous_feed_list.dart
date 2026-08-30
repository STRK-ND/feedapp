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

    // Flat lazy item list: cards are constructed only for visible rows,
    // and each entry carries its global index so the tap callback needs
    // no per-card indexOf lookup.
    final items = <_Item>[];
    for (final g in groups) {
      items.add(_Item.header(g));
      for (final e in g.items) {
        items.add(_Item.card(e));
      }
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final header = item.section;
        if (header != null) {
          return SectionEyebrow(
            label: header.label,
            count: header.items.length,
            density: header.density,
          );
        }
        final entry = item.entry!;
        return ListArticleCard(
          article: entry.article,
          index: entry.index,
          measure: measure,
          onTap: () => onTap(entry.index),
        );
      },
    );
  }
}

class _Section {
  final String label;
  final SectionDensity density;
  final List<_Entry> items;
  _Section(this.label, this.density, this.items);
}

class _Entry {
  final Article article;
  final int index;
  const _Entry(this.article, this.index);
}

class _Item {
  final _Section? section;
  final _Entry? entry;
  const _Item.header(this.section) : entry = null;
  const _Item.card(this.entry) : section = null;
}

List<_Section> _groupByRecency(List<Article> articles) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final todayList = <_Entry>[];
  final yesterdayList = <_Entry>[];
  final earlierList = <_Entry>[];

  for (var i = 0; i < articles.length; i++) {
    final a = articles[i];
    final dtDay = DateTime(a.pubDate.year, a.pubDate.month, a.pubDate.day);
    if (dtDay == today) {
      todayList.add(_Entry(a, i));
    } else if (dtDay == yesterday) {
      yesterdayList.add(_Entry(a, i));
    } else {
      earlierList.add(_Entry(a, i));
    }
  }

  // Sort newest first within each group.
  int byNewest(_Entry a, _Entry b) =>
      b.article.pubDate.compareTo(a.article.pubDate);
  todayList.sort(byNewest);
  yesterdayList.sort(byNewest);
  earlierList.sort(byNewest);

  return [
    if (todayList.isNotEmpty)
      _Section('Today', SectionDensity.relaxed, todayList),
    if (yesterdayList.isNotEmpty)
      _Section('Yesterday', SectionDensity.moderate, yesterdayList),
    if (earlierList.isNotEmpty)
      _Section('Earlier', SectionDensity.compact, earlierList),
  ];
}
