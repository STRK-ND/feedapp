/// Saved articles flow — rebuilt for the editorial design system.
///
/// Uses the same time-grouped section eyebrow pattern as ContinuousFeedList,
/// so the user sees the same visual language whether on Feed or Saved.
/// Each saved article renders compactly: mono source / Playfair title /
/// mono dateline. No photo grid — the editorial style preserves the
/// print-like calm.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/article.dart';
import '../l10n/generated/app_localizations.dart';
import '../providers/settings_notifier.dart';
import '../utils/design_tokens.dart';
import 'section_eyebrow.dart';

class BentoSavedArticlesGrid extends StatefulWidget {
  final List<Article> articles;
  final Function(int) onTap;
  final Function(int) onToggleSave;
  final Function(int) onDismiss;
  final bool isEmpty;

  const BentoSavedArticlesGrid({
    required this.articles,
    required this.onTap,
    required this.onToggleSave,
    required this.onDismiss,
    required this.isEmpty,
    super.key,
  });

  @override
  State<BentoSavedArticlesGrid> createState() => _BentoSavedArticlesGridState();
}

class _BentoSavedArticlesGridState extends State<BentoSavedArticlesGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: AppMotion.base)
      ..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BentoSavedArticlesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Replay entrance when list goes from empty → non-empty.
    if (oldWidget.articles.isEmpty && widget.articles.isNotEmpty) {
      _entrance.reset();
      _entrance.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmpty || widget.articles.isNotEmpty == false) {
      return _buildEmpty();
    }

    final groups = _groupByRecency(widget.articles);

    if (groups.isEmpty) return _buildEmpty();

    final items = <Widget>[];
    for (final g in groups) {
      items.add(
        SectionEyebrow(
          label: g.label,
          count: g.items.length,
          density: g.density,
        ),
      );
      for (var i = 0; i < g.items.length; i++) {
        final article = g.items[i];
        final globalIndex = widget.articles.indexOf(article);
        items.add(
          _SavedRow(
            article: article,
            onTap: () => widget.onTap(globalIndex),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              widget.onToggleSave(globalIndex);
            },
          ),
        );
      }
    }

    return Consumer<SettingsNotifier>(
      builder: (context, settings, _) {
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpacing.s16),
          children: items,
        );
      },
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.paperOnGround : AppColors.ink;
    final soft = isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s16,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.bookmark_outline_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.s5),
            Text(
              AppLocalizations.of(context).savedEmptyTitle,
              style: AppType.headlineSmall(color: ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s3),
            Text(
              AppLocalizations.of(context).savedEmptyHint,
              style: AppType.bodyLarge(color: soft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Group {
  final String label;
  final SectionDensity density;
  final List<Article> items;
  _Group(this.label, this.density, this.items);
}

/// Recency buckets for the Saved view. Public so the grouping logic (a
/// three-way Today / Yesterday / Earlier split — the prior code had a
/// dead "this week" branch that folded everything older-than-yesterday
/// together and could never reach Earlier) has a runnable check.
List<({String label, List<Article> items})> groupSavedByRecency(
  List<Article> articles, {
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
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

  void newestFirst(List<Article> l) =>
      l.sort((a, b) => b.pubDate.compareTo(a.pubDate));
  newestFirst(todayList);
  newestFirst(yesterdayList);
  newestFirst(earlierList);

  return [
    if (todayList.isNotEmpty) (label: 'Saved today', items: todayList),
    if (yesterdayList.isNotEmpty) (label: 'Yesterday', items: yesterdayList),
    if (earlierList.isNotEmpty) (label: 'Earlier', items: earlierList),
  ];
}

List<_Group> _groupByRecency(List<Article> articles) {
  final groups = groupSavedByRecency(articles);
  return groups
      .map(
        (g) => _Group(
          g.label,
          g.label == 'Saved today'
              ? SectionDensity.relaxed
              : (g.label == 'Yesterday'
                    ? SectionDensity.moderate
                    : SectionDensity.compact),
          g.items,
        ),
      )
      .toList();
}

/// Single saved-article row — mono source, Playfair title + truncated
/// description, mono dateline. No image by default; Saved should feel
/// like a reading index, not a magazine shelf.
class _SavedRow extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SavedRow({
    required this.article,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.paperOnGround : AppColors.ink;
    final soft = isDark ? AppColors.paperOnGroundSoft : AppColors.inkSoft;
    final ruleColor = isDark ? AppColors.ruleOnGround : AppColors.rule;
    final sourceColor = _sourceColor(article.sourceColor);

    return Semantics(
      button: true,
      label:
          '${article.title}. Saved from ${article.sourceName}. Tap to read, long press to remove.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s6,
            vertical: AppSpacing.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Source color dot for visual at-a-glance.
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: sourceColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Expanded(
                    child: Text(
                      article.sourceName.toUpperCase(),
                      style: AppType.monoEyebrow(
                        color: sourceColor,
                      ).copyWith(letterSpacing: 0.6),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s2),
                  Text(
                    _formatDateline(article.pubDate),
                    style: AppType.monoDateline(color: soft),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s2),
              Text(
                article.title,
                style: AppType.titleLarge(
                  color: ink,
                ).copyWith(fontSize: 18, height: 1.25),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (article.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(
                  article.description,
                  style: AppType.bodyMedium(color: soft).copyWith(height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.s3),
              // Hairline.
              SizedBox(height: 0.5, child: Container(color: ruleColor)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trim to "08/12 · 14:03" / "Yesterday" / "5D AGO" / "DD/MM/YY".
String _formatDateline(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dtDay = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(dtDay).inDays;
  if (diff == 0) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  if (diff == 1) return 'YESTERDAY';
  if (diff < 7) return '${diff}D AGO';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${(dt.year % 100).toString().padLeft(2, '0')}';
}

Color _sourceColor(String? hex) {
  if (hex == null || hex.isEmpty) return AppColors.primary;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length == 6) {
    return Color(int.parse('0xFF$cleaned'));
  }
  return AppColors.primary;
}
