import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/cache_manager.dart';
import '../utils/article_view.dart';
import '../services/rss_feed_service.dart';
import '../services/article_content_service.dart';
import '../services/tts_service.dart';
import '../providers/settings_notifier.dart';
import '../di/service_locator.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/summarize_service.dart';
import '../utils/constants.dart';
import '../utils/design_tokens.dart';
import '../utils/helpers.dart';
import '../utils/reader_theme.dart';
import 'reader_controls.dart';
import '../screens/paywall_screen.dart';

/// Expanded article card bottom sheet/modal widget
/// Features: Glassmorphism, hero image fade-in transitions,
/// reader-mode controls (theme swatches + Aa panel)
class ExpandedArticleCard extends StatefulWidget {
  final Article article;
  final VoidCallback onClose;
  final VoidCallback onToggleSave;

  const ExpandedArticleCard({
    required this.article,
    required this.onClose,
    required this.onToggleSave,
    super.key,
  });

  @override
  State<ExpandedArticleCard> createState() => _ExpandedArticleCardState();
}

class _ExpandedArticleCardState extends State<ExpandedArticleCard> {
  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool _isLoadingContent = false;
  String? _fullContent;

  /// True once the article has been marked read while open (R-4 gate:
  /// review prompt fires on reader close, and only after a read).
  bool _wasRead = false;
  bool _isProUser = false;

  // Listen mode. The service is a lazy singleton; this sheet drives its
  // state and stops playback on close.
  TtsService? _tts;
  TtsState _ttsState = TtsState.stopped;

  // Reader preferences are now sourced from the SettingsNotifier (which
  // is the single owner). Local copies are kept only as a brief in-
  // frame cache so we don't `read` on every widget rebuild; the
  // Consumer below triggers a rebuild on every notify.
  ReaderTheme _readerTheme = ReaderTheme.defaultTheme;
  double _fontSize = 16;
  double _lineHeight = 1.6;
  bool _widenMeasure = false;
  bool _monoDatelines = true;
  String _bodyFont = 'dm';

  @override
  void initState() {
    super.initState();
    _initContent();
    _loadPrefs();
    // The card opens already-marked-read from _onTapCard; treat any open
    // session as a completed read for the review-signal gate.
    _wasRead = widget.article.isRead;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listenToTts();
  }

  /// Late-bind the TtsService (getIt may not be ready in initState in
  /// tests) and subscribe for state changes.
  void _listenToTts() {
    if (_tts != null) return;
    try {
      final tts = getIt<TtsService>();
      tts.addListener(_onTtsChanged);
      setState(() {
        _tts = tts;
        _ttsState = tts.state;
      });
    } catch (_) {
      // TTS unavailable — the button hides itself via _tts == null.
    }
  }

  void _onTtsChanged() {
    if (!mounted) return;
    setState(() => _ttsState = _tts?.state ?? TtsState.stopped);
  }

  IconData get _ttsIcon => switch (_ttsState) {
    TtsState.playing => Icons.pause_rounded,
    TtsState.paused => Icons.play_arrow_rounded,
    TtsState.stopped => Icons.graphic_eq_rounded,
  };

  String get _ttsLabel => switch (_ttsState) {
    TtsState.playing => 'Pause',
    TtsState.paused => 'Resume',
    TtsState.stopped => 'Listen',
  };

  Future<void> _onListenTap() async {
    final tts = _tts;
    if (tts == null || !mounted) return;
    switch (_ttsState) {
      case TtsState.playing:
        await tts.pause();
      case TtsState.paused:
        await tts.resume();
      case TtsState.stopped:
        final body =
            (_fullContent ??
                    (widget.article.fullContent.isNotEmpty
                        ? widget.article.fullContent
                        : widget.article.description))
                .trim();
        final text = '${widget.article.title}. $body';
        unawaited(tts.speak(text));
    }
  }

  @override
  void dispose() {
    // R-4: closing the reader after a real read is the app's strongest
    // satisfaction signal. Gated to 90 days inside the service and never
    // fired for Pro users — payers get no nags, and Google caps the
    // prompt's real-world frequency anyway.
    if (_wasRead && !_isProUser) {
      unawaited(AnalyticsService.maybeRequestReview());
    }
    _tts?.removeListener(_onTtsChanged);
    // Leaving the reader always silences playback.
    unawaited(_tts?.stop());
    super.dispose();
  }

  // =========================================================================
  // AI summaries (market roadmap Tier 1, feature 4).
  // =========================================================================

  String? _summary;
  bool _isSummarizing = false;
  String? _summaryError;

  /// The body the worker would summarize — the effective reader body.
  String get _summarizableBody {
    final body =
        _fullContent ??
        (widget.article.fullContent.isNotEmpty
            ? widget.article.fullContent
            : widget.article.description);
    return body;
  }

  /// The action shows only when there is something substantial to
  /// summarize (the worker rejects bodies under 200 chars) and no
  /// summary is on screen yet.
  bool get _canShowSummarize {
    if (_summary != null) return false;
    if (_isSummarizing) return true;
    return _summarizableBody.trim().length >= kSummaryMinBodyChars;
  }

  Widget _buildSummarizeSection(ReaderPalette palette) {
    if (_summary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: palette.text,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _l10n.summaryTitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _summary!,
                  style: _bodyStyle().copyWith(
                    fontSize: 14,
                    color: palette.text,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (!_canShowSummarize) return const SizedBox.shrink();

    final l10n = _l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            if (_isSummarizing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.auto_awesome_rounded, size: 16),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _isSummarizing ? null : _onSummarize,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                _isSummarizing ? l10n.summarizingLabel : l10n.summarizeCta,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_summaryError != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    _summaryError!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _onSummarize() async {
    final articleId = widget.article.id;
    unawaited(AnalyticsService.logSummaryRequested(articleId: articleId));

    final service = getIt<SummarizeService>();
    final isPro = _isProUser;

    // Free users get a small monthly trial; past it, the demonstrated
    // intent routes to the paywall (R-1 pattern).
    if (!isPro) {
      final remaining = await service.remainingFreeTrial();
      if (!mounted) return;
      if (remaining <= 0) {
        unawaited(AnalyticsService.logSummaryLocked());
        unawaited(
          AnalyticsService.logPaywallShown(
            trigger: 'summary_trial',
            savedCount: 0,
          ),
        );
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PaywallScreen(entry: PaywallEntry.aiSummary),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSummarizing = true;
      _summaryError = null;
    });

    final result = await service.summarize(
      widget.article,
      persistentLookup: (id) => getIt<StorageService>().getSummary(id),
      persist: (id, text) => getIt<StorageService>().saveSummary(id, text),
    );
    if (!mounted) return;
    setState(() => _isSummarizing = false);

    switch (result.status) {
      case SummaryStatus.success:
        setState(() => _summary = result.summary);
        unawaited(AnalyticsService.logSummaryShown(articleId: articleId));
        if (!isPro) await service.recordFreeUse();
      case SummaryStatus.budgetExhausted:
        setState(() => _summaryError = _l10n.summaryBudgetSnack);
        unawaited(AnalyticsService.logSummaryError(articleId: articleId));
      case SummaryStatus.authFailed:
        setState(() => _summaryError = _l10n.summarySignInSnack);
        unawaited(AnalyticsService.logSummaryError(articleId: articleId));
      case SummaryStatus.rateLimited:
      case SummaryStatus.failed:
        setState(() => _summaryError = _l10n.summaryFailedSnack);
        unawaited(AnalyticsService.logSummaryError(articleId: articleId));
    }
  }

  Future<void> _loadPrefs() async {
    final notifier = context.read<SettingsNotifier>();
    if (!mounted) return;
    setState(() {
      _readerTheme = notifier.readerTheme;
      _fontSize = notifier.fontSize;
      _lineHeight = notifier.lineHeight;
      _widenMeasure = notifier.widenMeasure;
      _bodyFont = notifier.bodyFont;
      _monoDatelines = notifier.monoDatelines;
      _isProUser = notifier.isPro;
    });
  }

  Future<void> _persistTheme(ReaderTheme t) async {
    final notifier = context.read<SettingsNotifier>();
    if (isReaderThemeLocked(t, notifier.isPro)) {
      // R-1: keep the explanatory SnackBar, then route to the paywall —
      // the second Pro surface (after the save cap) also previously
      // dead-ended at a transient banner with no path to purchase.
      unawaited(
        AnalyticsService.logPaywallShown(trigger: 'theme_lock', savedCount: 0),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).proThemeLocked(t.label)),
          duration: const Duration(seconds: 2),
        ),
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const PaywallScreen(entry: PaywallEntry.themeLock),
        ),
      );
      return;
    }
    await notifier.setReaderTheme(t);
    if (mounted) setState(() => _readerTheme = t);
  }

  Future<void> _persistFontSize(double v) async {
    await context.read<SettingsNotifier>().setFontSize(v);
    if (mounted) setState(() => _fontSize = v);
  }

  Future<void> _persistLineHeight(double v) async {
    await context.read<SettingsNotifier>().setLineHeight(v);
    if (mounted) setState(() => _lineHeight = v);
  }

  Future<void> _persistWiden(bool v) async {
    await context.read<SettingsNotifier>().setWidenMeasure(v);
    if (mounted) setState(() => _widenMeasure = v);
  }

  Future<void> _persistBodyFont(String v) async {
    await context.read<SettingsNotifier>().setBodyFont(v);
    if (mounted) setState(() => _bodyFont = v);
  }

  Future<void> _initContent() async {
    // Check if we already have cached full content
    if (widget.article.fetchedFullContent != null) {
      if (mounted) {
        setState(() {
          _fullContent = widget.article.fetchedFullContent;
        });
      }
      return;
    }

    // P-1: the worker no longer sends `fullContent` (it was always a
    // byte-for-byte copy of `description`, costing 26% of every payload),
    // so ask the surviving field. Article.fromJson defaults fullContent
    // to '' for old cached rows, so fall back for pre-existing rows too.
    final summary = widget.article.fullContent.isNotEmpty
        ? widget.article.fullContent
        : widget.article.description;
    if (summary.length < 200) {
      await _fetchFullContent();
    } else {
      if (mounted) {
        setState(() {
          _fullContent = summary;
        });
      }
    }
  }

  Future<void> _fetchFullContent() async {
    if (!mounted) return;
    setState(() {
      _isLoadingContent = true;
    });

    try {
      final content = await getIt<ArticleContentService>().fetchArticleContent(
        widget.article.link,
      );
      if (!mounted) return;
      setState(() {
        _fullContent = content;
        _isLoadingContent = false;
      });

      // Cache the fetched content only if it's actual content
      if (!content.startsWith('Unable to extract') &&
          !content.startsWith('Failed to load')) {
        widget.article.fetchedFullContent = content;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fullContent = widget.article.fullContent.isNotEmpty
            ? widget.article.fullContent
            : widget.article.description;
        _isLoadingContent = false;
      });
    }
  }

  /// Hero image with fade-in transition animation
  Widget _buildFadeInImage(
    String imageUrl,
    double height,
    double borderRadius,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheManager: AppCacheManager(),
        // Decode cap mirrors card_stack.dart — full-resolution heroes
        // cost tens of MB of bitmap memory each.
        memCacheWidth: 800,
        fadeInDuration: AppMotion.base,
        fadeOutDuration: AppMotion.base,
        placeholder: (context, url) =>
            _buildImagePlaceholder(height, borderRadius),
        errorWidget: (context, url, error) =>
            _buildImageError(height, borderRadius),
      ),
    );
  }

  Widget _buildImagePlaceholder(double height, double borderRadius) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildImageError(double height, double borderRadius) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final registry = getIt.isRegistered<RssFeedService>()
        ? getIt<RssFeedService>()
        : null;
    final source = registry?.getSourceById(widget.article.sourceId);
    final sourceColor = widget.article.accent;
    final sourceName = source?.name ?? widget.article.sourceName;
    final sourceIcon = source?.icon ?? Icons.rss_feed_rounded;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<SettingsNotifier>(
      builder: (context, settings, _) {
        final showImages = settings.showImages;
        final imageMaxWidth = settings.imageMaxWidth.toDouble();
        // Mirror from the notifier so any external change (from Settings)
        // propagates live. The local setters above also call setX (which
        // notifies) so the Consumer will rebuild after our own writes
        // too — but using the notifier values directly avoids the
        // single-frame lag.
        _readerTheme = settings.readerTheme;
        _fontSize = settings.fontSize;
        _lineHeight = settings.lineHeight;
        _widenMeasure = settings.widenMeasure;
        _bodyFont = settings.bodyFont;
        _monoDatelines = settings.monoDatelines;
        _isProUser = settings.isPro;

        final palette = ReaderPalette.forTheme(
          theme: _readerTheme,
          appBrightness: Theme.of(context).brightness,
        );

        Widget buildHeaderButton({
          required IconData icon,
          required VoidCallback onPressed,
          required Color color,
          required String label,
        }) {
          return Container(
            margin: const EdgeInsets.only(left: 4),
            child: Semantics(
              button: true,
              label: label,
              child: IconButton(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                color: color,
                padding: const EdgeInsets.all(12),
                style: IconButton.styleFrom(
                  backgroundColor: color.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
              ),
            ),
          );
        }

        return Dismissible(
          direction: DismissDirection.vertical,
          key: Key('article_modal_${widget.article.id}'),
          onDismissed: (_) => widget.onClose(),
          child: DraggableScrollableSheet(
            initialChildSize: 1.0,
            minChildSize: 0.5,
            maxChildSize: 1.0,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: palette.ground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      blurRadius: 32,
                      offset: const Offset(0, -16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.rule,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Container(
                              decoration: AppCardStyles.chipDecoration(
                                sourceColor,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    sourceIcon,
                                    size: 14,
                                    color: sourceColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      sourceName,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: sourceColor,
                                        letterSpacing: 0.2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Server-extracted full text (teaser feeds):
                          // the reader is showing the whole article, not
                          // the feed's teaser body. Matches the header
                          // buttons' hardcoded-label style.
                          if (widget.article.fullContent.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: palette.soft,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.badge,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.article_rounded,
                                    size: 14,
                                    color: palette.text,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Full text',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: palette.text,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_tts != null)
                                    buildHeaderButton(
                                      icon: _ttsIcon,
                                      onPressed: _onListenTap,
                                      color: sourceColor,
                                      label: _ttsLabel,
                                    ),
                                  buildHeaderButton(
                                    icon: Icons.open_in_new_rounded,
                                    onPressed: () async {
                                      final uri = Uri.parse(
                                        widget.article.link,
                                      );
                                      // Scheme allowlist: the link comes from
                                      // feed content, so only real web URLs may
                                      // leave the app (blocks intent:// and
                                      // other app-handoff schemes).
                                      if (uri.scheme != 'http' &&
                                          uri.scheme != 'https') {
                                        return;
                                      }
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    color: sourceColor,
                                    label: 'Open in browser',
                                  ),
                                  buildHeaderButton(
                                    icon: Icons.share_rounded,
                                    onPressed: () {
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              '${widget.article.title}\n\n${widget.article.link}',
                                        ),
                                      );
                                    },
                                    color: sourceColor,
                                    label: 'Share article',
                                  ),
                                  buildHeaderButton(
                                    icon: widget.article.isSaved
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    onPressed: () {
                                      widget.onToggleSave();
                                      setState(() {});
                                    },
                                    color: widget.article.isSaved
                                        ? colorScheme.error
                                        : sourceColor,
                                    label: widget.article.isSaved
                                        ? 'Saved'
                                        : 'Save',
                                  ),
                                  buildHeaderButton(
                                    icon: Icons.close_rounded,
                                    onPressed: widget.onClose,
                                    color: palette.soft,
                                    label: 'Close',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: palette.rule),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: _widenMeasure ? 840 : 640,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showImages &&
                                    widget.article.imageUrl != null)
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: imageMaxWidth,
                                    ),
                                    child: _buildFadeInImage(
                                      widget.article.imageUrl!,
                                      220,
                                      AppRadius.image,
                                    ),
                                  ),
                                if (showImages &&
                                    widget.article.imageUrl != null)
                                  const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      if (widget.article.author != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration:
                                              AppCardStyles.chipDecoration(
                                                sourceColor,
                                              ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person_outline_rounded,
                                                size: 13,
                                                color: sourceColor,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                widget.article.author!,
                                                style: GoogleFonts.dmSans(
                                                  fontSize: 12,
                                                  color: sourceColor,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                      ],
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: palette.soft,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        Helpers.formatDate(
                                          widget.article.pubDate,
                                        ),
                                        style:
                                            (_monoDatelines
                                            ? GoogleFonts.jetBrainsMono
                                            : GoogleFonts.dmSans)(
                                              fontSize: 13,
                                              color: palette.soft,
                                              letterSpacing: 0.1,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s2),
                                // Reader-mode controls: theme swatches + Aa.
                                ReaderControls(
                                  currentTheme: _readerTheme,
                                  fontSize: _fontSize,
                                  lineHeight: _lineHeight,
                                  widenMeasure: _widenMeasure,
                                  bodyFont: _bodyFont,
                                  isPro: settings.isPro,
                                  onTheme: _persistTheme,
                                  onFontSize: _persistFontSize,
                                  onLineHeight: _persistLineHeight,
                                  onWidenMeasure: _persistWiden,
                                  onBodyFont: _persistBodyFont,
                                  onLockedTheme: (t) {
                                    // R-1: route the locked swatch to the
                                    // paywall as well as explaining it.
                                    unawaited(
                                      AnalyticsService.logPaywallShown(
                                        trigger: 'theme_lock',
                                        savedCount: 0,
                                      ),
                                    );
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const PaywallScreen(
                                          entry: PaywallEntry.themeLock,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.s5),
                                Text(
                                  widget.article.title,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: palette.text,
                                    height: 1.35,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                _buildSummarizeSection(palette),
                                const SizedBox(height: 20),
                                Builder(
                                  builder: (context) {
                                    final hasFullContent =
                                        _fullContent != null &&
                                        _fullContent!.trim().isNotEmpty;
                                    final isContentIdentical =
                                        hasFullContent &&
                                        _fullContent!.trim() ==
                                            widget.article.description.trim();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!isContentIdentical &&
                                            widget
                                                .article
                                                .description
                                                .isNotEmpty) ...[
                                          SelectableText(
                                            widget.article.description,
                                            style: _bodyStyle().copyWith(
                                              fontSize: _fontSize,
                                              color: palette.text,
                                              height: _lineHeight,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                        ],
                                        if (_isLoadingContent)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 40,
                                            ),
                                            child: Center(
                                              child: Column(
                                                children: [
                                                  CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(sourceColor),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  Text(
                                                    AppLocalizations.of(
                                                      context,
                                                    ).loadingFullArticle,
                                                    style: GoogleFonts.dmSans(
                                                      fontSize: 14,
                                                      color: palette.soft,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        else if (hasFullContent)
                                          SelectableText(
                                            _fullContent!,
                                            style: _bodyStyle().copyWith(
                                              fontSize: isContentIdentical
                                                  ? _fontSize
                                                  : _fontSize - 1,
                                              color: isContentIdentical
                                                  ? palette.text
                                                  : palette.soft,
                                              height: isContentIdentical
                                                  ? _lineHeight
                                                  : _lineHeight + 0.1,
                                              letterSpacing: 0.05,
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Body font for the article text. 'dm' → DM Sans; 'lora' → Lora.
  TextStyle _bodyStyle() {
    if (_bodyFont == 'lora') {
      return GoogleFonts.lora(fontWeight: FontWeight.w400);
    }
    return GoogleFonts.dmSans(fontWeight: FontWeight.w400);
  }
}
