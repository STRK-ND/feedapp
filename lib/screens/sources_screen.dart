/// Sources screen — manage subscribed feeds, browse curated sources, and
/// import OPML (deferred).
///
/// Reached from Settings → "Manage sources". The top of the screen shows
/// currently subscribed sources with per-source unread counts and a
/// long-press to unsubscribe. Below is a "Discover" section grouped by
/// category with a tappable cell to add a new source.
///
/// This addresses the biggest UX gap in the app: previously sources were
/// hardcoded and there was no way to manage them at all.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/design_tokens.dart';
import '../models/rss_source.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  // In-memory subscription set. Real persistence will plug into a
  // `UserSourceRepository` (deferred); this scaffolds the UI without
  // rewriting storage today.
  final _subscriptions = <String>{'the-verge', 'bbc', 'aeon'};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Sources',
          style: AppType.headlineSmall(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, AppSpacing.s16),
        children: [
          _buildSectionHeader(
            'SUBSCRIBED',
            trailing: '${_subscriptions.length} active',
          ),
          const SizedBox(height: AppSpacing.s3),
          ..._discoverSources
              .where((s) => _subscriptions.contains(s.id))
              .map((s) => _SourceTile(
                    source: s,
                    unread: _mockUnread(s.id),
                    isSubscribed: true,
                    onTap: () => _uncheck(s),
                    onLongPress: () => _confirmUnsub(s),
                  )),
          const SizedBox(height: AppSpacing.s8),
          _buildSectionHeader(
            'DISCOVER',
            trailing: 'tap to add',
          ),
          const SizedBox(height: AppSpacing.s3),
          for (final category in _categoryOrder) ...[
            _CategoryGroup(
              category: category,
              sources: _discoverSources
                  .where((s) => s.category == category)
                  .toList(),
              subscriptions: _subscriptions,
              onToggle: _toggle,
            ),
            const SizedBox(height: AppSpacing.s5),
          ],
          const SizedBox(height: AppSpacing.s12),
          Center(
            child: Text(
              'OPML import — coming soon',
              style: AppType.monoEyebrow(color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
      child: Row(
        children: [
          Text(label, style: AppType.monoEyebrow(color: AppColors.inkSoft)),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing.toUpperCase(),
              style: AppType.monoEyebrow(color: AppColors.inkSoft)
                  .copyWith(letterSpacing: 0.6),
            ),
        ],
      ),
    );
  }

  void _toggle(RssSource s) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_subscriptions.contains(s.id)) {
        _subscriptions.remove(s.id);
      } else {
        _subscriptions.add(s.id);
      }
    });
  }

  void _uncheck(RssSource s) {
    // Tap on subscribed = filter feed to this source (would be wired to
    // a callback in the real impl).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filter the feed to "${s.name}" — coming soon'),
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  Future<void> _confirmUnsub(RssSource s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unsubscribe from ${s.name}?'),
        content: const Text(
          'Articles from this source will no longer appear in your feed. '
          '\n\nYou can re-subscribe any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _subscriptions.remove(s.id));
    }
  }
}

int _mockUnread(String id) {
  // Deterministic-looking fake counts so the design is testable without
  // wiring real notifications yet.
  return id.hashCode.abs() % 8;
}

const _categoryOrder = ['News', 'Tech', 'Essays', 'Politics', 'Daily digest'];

const _discoverSources = [
  RssSource(
    id: 'the-verge',
    name: 'The Verge',
    url: '',
    category: 'Tech',
    color: Color(0xFFFF0000),
    icon: Icons.privacy_tip_outlined,
  ),
  RssSource(
    id: 'bbc',
    name: 'BBC News',
    url: '',
    category: 'News',
    color: Color(0xFFE63946),
    icon: Icons.public,
  ),
  RssSource(
    id: 'aeon',
    name: 'Aeon',
    url: '',
    category: 'Essays',
    color: Color(0xFF6B7280),
    icon: Icons.menu_book_outlined,
  ),
  RssSource(
    id: 'reuters',
    name: 'Reuters',
    url: '',
    category: 'News',
    color: Color(0xFFFF8800),
    icon: Icons.gavel,
  ),
  RssSource(
    id: 'ars-technica',
    name: 'Ars Technica',
    url: '',
    category: 'Tech',
    color: Color(0xFF3B82F6),
    icon: Icons.memory,
  ),
  RssSource(
    id: 'lrb',
    name: 'LRB Blog',
    url: '',
    category: 'Essays',
    color: Color(0xFFDC2626),
    icon: Icons.book,
  ),
  RssSource(
    id: 'fivethirtyeight',
    name: 'FiveThirtyEight',
    url: '',
    category: 'Politics',
    color: Color(0xFF1E40AF),
    icon: Icons.bar_chart,
  ),
  RssSource(
    id: 'the-browser',
    name: 'The Browser',
    url: '',
    category: 'Daily digest',
    color: Color(0xFF7C3AED),
    icon: Icons.language,
  ),
  RssSource(
    id: 'hacker-news',
    name: 'Hacker News',
    url: '',
    category: 'Tech',
    color: Color(0xFFFB923C),
    icon: Icons.terminal,
  ),
];

class _SourceTile extends StatelessWidget {
  final RssSource source;
  final int unread;
  final bool isSubscribed;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SourceTile({
    required this.source,
    required this.unread,
    required this.isSubscribed,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: source.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Icon(source.icon, size: 18, color: source.color),
            ),
            const SizedBox(width: AppSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.name, style: AppType.titleMedium()),
                  const SizedBox(height: 2),
                  Text(
                    '$unread unread',
                    style: AppType.monoDateline(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2 + 2, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.rule.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                source.category.toUpperCase(),
                style: AppType.monoEyebrow(color: AppColors.inkSoft)
                    .copyWith(letterSpacing: 0.6, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final String category;
  final List<RssSource> sources;
  final Set<String> subscriptions;
  final ValueChanged<RssSource> onToggle;

  const _CategoryGroup({
    required this.category,
    required this.sources,
    required this.subscriptions,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
          child: Text(
            category.toUpperCase(),
            style: AppType.monoEyebrow(color: AppColors.inkSoft)
                .copyWith(fontSize: 10, letterSpacing: 1.0),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        for (final s in sources) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2, vertical: AppSpacing.s2),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggle(s),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: s.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: Icon(s.icon, size: 14, color: s.color),
                  ),
                  const SizedBox(width: AppSpacing.s3),
                  Expanded(
                    child: Text(s.name,
                        style: AppType.titleMedium()
                            .copyWith(fontSize: 14)),
                  ),
                  AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: subscriptions.contains(s.id)
                          ? AppColors.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: subscriptions.contains(s.id)
                            ? AppColors.primary
                            : AppColors.rule,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: subscriptions.contains(s.id)
                        ? const Icon(Icons.check,
                            size: 12, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
