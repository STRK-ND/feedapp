/// Sources screen — manage subscribed feeds, browse curated sources, and
/// import OPML.
///
/// Reached from Settings → "Manage sources". The top of the screen shows
/// subscribed sources with per-source unread counts; tap a source to open
/// its feed, long-press to unsubscribe. Below is a "Discover" section
/// grouped by category with a tappable cell to add a new source.
/// Subscriptions persist via SettingsService and are read by FeedScreen to
/// filter the user's visible feed.
library;

import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../di/service_locator.dart';
import '../models/rss_source.dart';
import '../repositories/article_repository.dart';
import '../services/rss_feed_service.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart' hide AppColors;
import '../utils/design_tokens.dart';
import 'feed_screen.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  Set<String> _subscriptions = {};
  bool _loading = true;
  Map<String, int> _unreadBySource = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = getIt<SettingsService>();
    final subs = await settings.getSubscribedSourceIds();

    // Per-source unread counts for the subscribed list. Reads the article
    // cache (hydrated at splash) — a cheap in-memory lookup.
    final unread = <String, int>{};
    final articles = await getIt<ArticleRepository>().fetchAllArticles();
    if (articles.data != null) {
      for (final a in articles.data!) {
        if (!a.isRead) {
          unread[a.sourceId] = (unread[a.sourceId] ?? 0) + 1;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _subscriptions = subs;
      _unreadBySource = unread;
      _loading = false;
    });
  }

  String _unreadSubtitle(RssSource s) {
    final count = _unreadBySource[s.id] ?? 0;
    return count == 0 ? 'All caught up' : '$count unread';
  }

  Future<void> _toggle(RssSource s) async {
    unawaited(HapticFeedback.selectionClick());
    final next = Set<String>.from(_subscriptions);
    if (next.contains(s.id)) {
      next.remove(s.id);
    } else {
      next.add(s.id);
    }
    setState(() => _subscriptions = next);
    await getIt<SettingsService>().setSubscribedSourceIds(next);
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
      await _toggle(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Group canonical sources by category in stable order.
    final byCategory = <String, List<RssSource>>{};
    for (final s in RssFeedService.predefinedSources) {
      byCategory.putIfAbsent(s.category, () => []).add(s);
    }
    final categories = byCategory.keys.toList();

    final subscribed = RssFeedService.predefinedSources
        .where((s) => _subscriptions.contains(s.id))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Sources', style: AppType.headlineSmall()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s4,
          AppSpacing.s4,
          AppSpacing.s4,
          AppSpacing.s16,
        ),
        children: [
          _buildSectionHeader(
            'SUBSCRIBED',
            trailing: '${subscribed.length} active',
          ),
          const SizedBox(height: AppSpacing.s3),
          if (subscribed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2,
                vertical: AppSpacing.s4,
              ),
              child: Text(
                'No sources yet. Pick from DISCOVER below.',
                style: AppType.bodyMedium(color: AppColors.inkSoft),
              ),
            )
          else
            ...subscribed.map(
              (s) => _SourceTile(
                source: s,
                subtitle: _unreadSubtitle(s),
                isSubscribed: true,
                onTap: () => _openSource(s),
                onLongPress: () => _confirmUnsub(s),
              ),
            ),
          const SizedBox(height: AppSpacing.s8),
          _buildSectionHeader('DISCOVER', trailing: 'tap to add'),
          const SizedBox(height: AppSpacing.s3),
          for (final category in categories) ...[
            _CategoryGroup(
              category: category,
              sources: byCategory[category]!,
              subscriptions: _subscriptions,
              onToggle: _toggle,
            ),
            const SizedBox(height: AppSpacing.s5),
          ],
          const SizedBox(height: AppSpacing.s12),
          Center(
            child: Semantics(
              button: true,
              label: 'Import OPML file',
              child: InkWell(
                onTap: _importOpml,
                borderRadius: BorderRadius.circular(AppRadius.chip),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s3,
                    vertical: AppSpacing.s4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.upload_file_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.s2),
                      Text(
                        'Import OPML',
                        style: AppType.monoEyebrow(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
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
              style: AppType.monoEyebrow(
                color: AppColors.inkSoft,
              ).copyWith(letterSpacing: 0.6),
            ),
        ],
      ),
    );
  }

  /// Open a feed locked to this single source (unread-first, same as the
  /// main feed tab but filtered by [RssSource.id]).
  void _openSource(RssSource s) {
    unawaited(HapticFeedback.selectionClick());
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RssFeedScreen(sourceId: s.id)));
  }

  /// Pick an .opml / .xml file, extract outline URLs, match them against
  /// known canonical sources, and subscribe the user to all matches.
  /// Unknown URLs are skipped (we only support feeds from the canonical
  /// list — arbitrary custom-source support is out of scope for v1).
  Future<void> _importOpml() async {
    try {
      // withData keeps the picked bytes in memory — Android SAF can
      // return a null path otherwise. Deprecated in file_picker 12.x
      // but still functional; readAsBytes() below is the non-deprecated
      // way to consume them.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['opml', 'xml'],
        // ignore: deprecated_member_use
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final bytes = await result.files.single.readAsBytes();

      if (bytes.length > AppConfig.maxXmlSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File too large')));
        return;
      }

      final text = utf8.decode(bytes);
      final urls = _parseOpmlUrls(text);

      if (urls.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No feed URLs found in OPML file')),
        );
        return;
      }

      // Match OPML URLs to canonical sources (by source.url)
      final matching = RssFeedService.predefinedSources
          .where((s) => urls.contains(s.url))
          .map((s) => s.id)
          .toSet();

      if (matching.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${urls.length} feed URLs but none match Curated Feeds sources. '
              'Only Curated Feeds sources are supported.',
            ),
          ),
        );
        return;
      }

      final merged = {..._subscriptions, ...matching};
      setState(() => _subscriptions = merged);
      await getIt<SettingsService>().setSubscribedSourceIds(merged);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${matching.length} source(s)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  /// Pull every xmlUrl (and htmlUrl as fallback) out of an OPML document.
  Set<String> _parseOpmlUrls(String opmlText) {
    final urls = <String>{};
    try {
      final doc = XmlDocument.parse(opmlText);
      for (final outline in doc.findAllElements('outline')) {
        final xmlUrl = outline.getAttribute('xmlUrl');
        if (xmlUrl != null && xmlUrl.isNotEmpty) {
          urls.add(xmlUrl);
          continue;
        }
        final htmlUrl = outline.getAttribute('htmlUrl');
        if (htmlUrl != null && htmlUrl.isNotEmpty) {
          urls.add(htmlUrl);
        }
      }
    } catch (e) {
      // Fallback regex for slightly malformed OPML — grabs xmlUrl attributes.
      final xmlUrlRe = RegExp(r'xmlUrl="([^"]+)"');
      for (final m in xmlUrlRe.allMatches(opmlText)) {
        urls.add(m.group(1)!);
      }
    }
    return urls;
  }
}

class _SourceTile extends StatelessWidget {
  final RssSource source;
  final String subtitle;
  final bool isSubscribed;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SourceTile({
    required this.source,
    required this.subtitle,
    required this.isSubscribed,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${source.name}. $subtitle. Tap to open feed, long-press to '
          'unsubscribe.',
      child: GestureDetector(
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
                      subtitle,
                      style: AppType.monoDateline(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s2 + 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.rule.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  source.category.toUpperCase(),
                  style: AppType.monoEyebrow(
                    color: AppColors.inkSoft,
                  ).copyWith(letterSpacing: 0.6, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final String category;
  final List<RssSource> sources;
  final Set<String> subscriptions;
  final Future<void> Function(RssSource) onToggle;

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
            style: AppType.monoEyebrow(
              color: AppColors.inkSoft,
            ).copyWith(fontSize: 10, letterSpacing: 1.0),
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        for (final s in sources) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s2,
              vertical: AppSpacing.s3,
            ),
            child: Semantics(
              button: true,
              selected: subscriptions.contains(s.id),
              label: subscriptions.contains(s.id)
                  ? '${s.name}. Subscribed. Tap to unsubscribe.'
                  : '${s.name}. Tap to subscribe.',
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
                      child: Text(
                        s.name,
                        style: AppType.titleMedium().copyWith(fontSize: 14),
                      ),
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
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
