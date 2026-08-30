/// Sources screen — manage subscribed feeds, browse curated sources, add
/// custom feeds, and import/export OPML.
///
/// Reached from Settings → "Manage sources". The top of the screen shows
/// subscribed sources (canonical plus user-added customs) with per-source
/// unread counts; tap a source to open its feed, long-press a canonical
/// source to unsubscribe or a custom one to remove it entirely. Below is
/// a "Discover" section grouped by category, an "add feed URL" row for
/// arbitrary RSS/Atom feeds (fetched client-side), and OPML import/export.
/// Subscriptions persist via SettingsService and are read by FeedScreen to
/// filter the user's visible feed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../di/service_locator.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/rss_source.dart';
import '../repositories/article_repository.dart';
import '../services/rss_feed_service.dart';
import '../services/settings_service.dart';
import '../utils/constants.dart' hide AppColors;
import '../utils/design_tokens.dart';
import '../utils/error_handler.dart';
import '../utils/opml.dart';
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
  List<RssSource> _customSources = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Refresh the source registry in the background; when the worker's
    // canonical list lands, rebuild so Discover reflects it. Offline this
    // fails silently and the cached/seed list is used.
    unawaited(
      getIt<RssFeedService>().refreshFromWorker().then((_) {
        if (mounted) setState(() {});
      }),
    );
    final settings = getIt<SettingsService>();
    final subs = await settings.getSubscribedSourceIds();
    final customs = await settings.getCustomSources();

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
      _customSources = customs;
      _unreadBySource = unread;
      _loading = false;
    });
  }

  String _unreadSubtitle(RssSource s) {
    final l10n = AppLocalizations.of(context);
    final count = _unreadBySource[s.id] ?? 0;
    return count == 0
        ? l10n.sourceUnsubscribedSubtitle
        : l10n.sourceUnreadCount(count);
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.unsubscribeTitle(s.name)),
        content: Text(l10n.unsubscribeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.dialogKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.dialogUnsubscribe),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _toggle(s);
    }
  }

  /// Long-press on a custom source: unsubscribes AND deletes it entirely
  /// (custom feeds don't appear in DISCOVER, so unsubscribe alone would
  /// leave an orphan).
  Future<void> _confirmRemoveCustom(RssSource s) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeSourceTitle(s.name)),
        content: Text(l10n.removeSourceBody(s.url)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.dialogKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.dialogRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    unawaited(HapticFeedback.selectionClick());
    await getIt<SettingsService>().removeCustomSource(s.id);
    await _load();
  }

  /// Sheet prompting for a feed URL (+ optional display name). On save the
  /// source is persisted and subscribed; articles flow in on next refresh.
  Future<void> _showAddSourceSheet() async {
    final urlController = TextEditingController();
    final nameController = TextEditingController();
    String? errorText;

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheetTop),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void submit() async {
            final url = urlController.text.trim();
            final uri = Uri.tryParse(url);
            if (uri == null ||
                !uri.hasScheme ||
                !(uri.scheme == 'http' || uri.scheme == 'https') ||
                uri.host.isEmpty) {
              setSheetState(
                () => errorText = AppLocalizations.of(ctx).invalidUrlError,
              );
              return;
            }
            final settings = getIt<SettingsService>();
            await settings.addCustomSource(nameController.text, url);
            final customs = await settings.getCustomSources();
            final created = customs.firstWhere(
              (s) => s.url.toLowerCase() == url.toLowerCase(),
            );
            final subs = await settings.getSubscribedSourceIds();
            subs.add(created.id);
            await settings.setSubscribedSourceIds(subs);
            if (ctx.mounted) Navigator.pop(ctx, true);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.s4,
              right: AppSpacing.s4,
              top: AppSpacing.s5,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.s5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(ctx).addSheetTitle,
                  style: AppType.headlineSmall(),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  AppLocalizations.of(ctx).addSheetSubtitle,
                  style: AppType.bodyMedium(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                TextField(
                  controller: urlController,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(ctx).feedUrlLabel,
                    hintText: AppLocalizations.of(ctx).feedUrlHint,
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => submit(),
                ),
                const SizedBox(height: AppSpacing.s3),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(ctx).nameOptionalLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: submit,
                    child: Text(AppLocalizations.of(ctx).addSourceCta),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (added == true && mounted) {
      unawaited(HapticFeedback.selectionClick());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).sourceAddedSnack)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Group canonical sources by category in stable order.
    final canonicalSources = getIt<RssFeedService>().sources;
    final byCategory = <String, List<RssSource>>{};
    for (final s in canonicalSources) {
      byCategory.putIfAbsent(s.category, () => []).add(s);
    }
    final categories = byCategory.keys.toList();

    final subscribedCanonical = canonicalSources
        .where((s) => _subscriptions.contains(s.id))
        .toList();
    final subscribedCustom = _customSources
        .where((s) => _subscriptions.contains(s.id))
        .toList();
    final subscribedCount =
        subscribedCanonical.length + subscribedCustom.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(l10n.sourcesTitle, style: AppType.headlineSmall()),
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
            l10n.sourcesSubscribedLabel,
            trailing: l10n.sourcesActiveCount(subscribedCount),
          ),
          const SizedBox(height: AppSpacing.s3),
          if (subscribedCount == 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s2,
                vertical: AppSpacing.s4,
              ),
              child: Text(
                l10n.sourcesEmptyHint,
                style: AppType.bodyMedium(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            ...subscribedCustom.map(
              (s) => _SourceTile(
                source: s,
                subtitle: _unreadSubtitle(s),
                isSubscribed: true,
                onTap: () => _openSource(s),
                onLongPress: () => _confirmRemoveCustom(s),
              ),
            ),
            ...subscribedCanonical.map(
              (s) => _SourceTile(
                source: s,
                subtitle: _unreadSubtitle(s),
                isSubscribed: true,
                onTap: () => _openSource(s),
                onLongPress: () => _confirmUnsub(s),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          _buildSectionHeader(
            l10n.sourcesDiscoverLabel,
            trailing: l10n.sourcesTapToAdd,
          ),
          const SizedBox(height: AppSpacing.s3),
          _AddSourceTile(onTap: _showAddSourceSheet),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                button: true,
                label: l10n.exportOpmlSemantic,
                child: InkWell(
                  onTap: _exportOpml,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s3,
                      vertical: AppSpacing.s4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        Text(
                          l10n.exportOpmlLabel,
                          style: AppType.monoEyebrow(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s6),
              Semantics(
                button: true,
                label: l10n.importOpmlSemantic,
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
                        Icon(
                          Icons.upload_file_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: AppSpacing.s2),
                        Text(
                          l10n.importOpmlLabel,
                          style: AppType.monoEyebrow(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, {String? trailing}) {
    final soft = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
      child: Row(
        children: [
          Text(label, style: AppType.monoEyebrow(color: soft)),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing.toUpperCase(),
              style: AppType.monoEyebrow(
                color: soft,
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
    final l10n = AppLocalizations.of(context);
    try {
      // withData keeps the picked bytes in memory — Android SAF can
      // return a null path otherwise. Deprecated in file_picker 12.x
      // but still functional; readAsBytes() below is the non-deprecated
      // way to consume them.
      // file_picker 12.x: pickFiles returns the file list directly.
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['opml', 'xml'],
        // ignore: deprecated_member_use
        withData: true,
      );
      if (!mounted || result.isEmpty) return;
      final bytes = await result.single.readAsBytes();

      if (bytes.length > AppConfig.maxXmlSizeBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.opmlFileTooLarge)));
        return;
      }

      final text = utf8.decode(bytes);
      final urls = parseOpmlUrls(text);

      if (urls.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.opmlNoUrlsFound)));
        return;
      }

      // Match OPML URLs to canonical sources (by source.url)
      final matching = matchCanonicalSources(
        urls,
        getIt<RssFeedService>().sources,
      );

      if (matching.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.opmlNoMatches(urls.length))),
        );
        return;
      }

      final merged = {..._subscriptions, ...matching};
      setState(() => _subscriptions = merged);
      await getIt<SettingsService>().setSubscribedSourceIds(merged);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.opmlImported(matching.length))),
      );
    } catch (e) {
      // Log the raw error; show only a generic message — exception text can
      // leak paths/internal details and reads as noise to users.
      unawaited(ErrorHandler.logError('OPML import failed', error: e));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).opmlImportFailed)),
      );
    }
  }

  /// Serialize subscribed sources (canonical + custom) to OPML 2.0, write
  /// it to a temp file, and hand it to the Android share sheet (save
  /// locally, email it, send to another reader — user's choice).
  Future<void> _exportOpml() async {
    try {
      final subscribed = [
        ...getIt<RssFeedService>().sources,
        ..._customSources,
      ].where((s) => _subscriptions.contains(s.id)).toList();

      if (subscribed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).opmlNothingToExport),
          ),
        );
        return;
      }

      final xml = buildOpmlDocument(
        subscribed,
        title: 'Curated Feeds subscriptions',
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/curated-feeds-subscriptions.opml');
      await file.writeAsString(xml, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Curated Feeds subscriptions',
        ),
      );
      ErrorHandler.addBreadcrumb(
        'OPML exported (${subscribed.length} sources), share status: ${result.status}',
        category: 'sources',
      );
    } catch (e) {
      unawaited(ErrorHandler.logError('OPML export failed', error: e));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).opmlExportFailed)),
      );
    }
  }
}

/// Tappable "add a custom feed" row shown above the DISCOVER groups.
class _AddSourceTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AddSourceTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).sourcesAddCustomSemantic,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s2,
            vertical: AppSpacing.s3,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s3),
              Text(
                AppLocalizations.of(context).sourcesAddFeedUrl,
                style: AppType.monoEyebrow(
                  color: cs.onSurface,
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
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
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: AppLocalizations.of(
        context,
      ).sourceTileSemantic(source.name, subtitle),
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
                      style: AppType.monoDateline(color: cs.onSurfaceVariant),
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
                  color: cs.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                ),
                child: Text(
                  source.category.toUpperCase(),
                  style: AppType.monoEyebrow(
                    color: cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
          child: Text(
            category.toUpperCase(),
            style: AppType.monoEyebrow(
              color: cs.onSurfaceVariant,
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
                  ? AppLocalizations.of(
                      context,
                    ).sourceSubscribedSemantic(s.name)
                  : AppLocalizations.of(
                      context,
                    ).sourceNotSubscribedSemantic(s.name),
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
                              : cs.outline,
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
