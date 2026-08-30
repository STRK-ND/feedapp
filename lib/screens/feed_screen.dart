import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/article.dart';
import '../l10n/generated/app_localizations.dart';
import '../repositories/article_repository.dart';
import '../services/storage_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_notifier.dart';
import '../services/analytics_service.dart';
import '../widgets/card_stack.dart';
import '../widgets/continuous_feed_list.dart';
import '../widgets/expanded_article_card.dart';
import '../widgets/folio_rule.dart';
import '../widgets/update_dialog.dart';
import '../widgets/bento_saved_articles.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/grain_overlay.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../services/rss_feed_service.dart';
import '../di/service_locator.dart';
import 'settings_screen.dart';

/// Main RSS Feed Screen - Card view only
class RssFeedScreen extends StatefulWidget {
  final bool showSavedArticles;

  /// When set, the feed is locked to a single source (drill-in from the
  /// Sources screen). The app bar shows the source name and category
  /// chips / Folio Rule are hidden so the view reads as a focused list.
  final String? sourceId;

  const RssFeedScreen({
    super.key,
    this.showSavedArticles = false,
    this.sourceId,
  });

  @override
  State<RssFeedScreen> createState() => _RssFeedScreenState();
}

class _RssFeedScreenState extends State<RssFeedScreen>
    with WidgetsBindingObserver {
  List<Article> _articles = [];
  List<Article> _savedArticles = [];
  List<Article> _displayedArticles = [];
  String _selectedFilter = 'All';
  int _selectedTab = 0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _autoRefreshEnabled = true; // lifted by lifecycle observer
  DateTime? _lastRefreshTime;
  bool _isOnline = true;
  bool _isSearchActive = false;
  String _searchQuery = '';
  String _viewMode = 'stack'; // 'stack' or 'continuous'
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _autoRefreshTimer;
  Timer? _searchDebounceTimer;
  StreamSubscription<void>? _cloudSyncSub;
  // Single-flight guard for refresh calls (manually tap, connectivity
  // tick, auto-refresh tick can all fire close together). Drains the
  // call heap to one in-flight; the rest become no-ops.
  Future<void>? _refreshInFlight;
  // Time of last successful refresh; suppresses repeat calls within
  // this window even when no current in-flight call exists.
  DateTime? _lastRefreshAt;

  final List<String> _categories = AppConfig.categories;
  final Connectivity _connectivity = Connectivity();
  final StorageService _storage = getIt<StorageService>();
  final ArticleRepository _articleRepository = getIt<ArticleRepository>();
  final SettingsService _settingsService = getIt<SettingsService>();
  // Subscribed source IDs — loaded from SettingsService. Empty set means
  // "no filter applied yet" (first run before _loadSubscribedIds returns).
  Set<String> _subscribedIds = {};

  int get _unreadCount =>
      _articles.where((a) => !a.isRead && !a.isSaved).length;
  TextTheme get _textTheme => Theme.of(context).textTheme;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// App-bar title. A source drill-in shows the source name so the view
  /// reads as "the Verge" rather than a generic feed header.
  String get _appBarTitle {
    final sourceId = widget.sourceId;
    if (sourceId != null) {
      return getIt<RssFeedService>().getSourceById(sourceId)?.name ??
          _l10n.navFeed;
    }
    switch (_selectedTab) {
      case 1:
        return _l10n.navSaved;
      case 2:
        return _l10n.navSettings;
      default:
        return 'Curated Feeds';
    }
  }

  Future<void> _loadSubscribedIds() async {
    final ids = await _settingsService.getSubscribedSourceIds();
    if (!mounted) return;
    setState(() {
      _subscribedIds = ids;
      _displayedArticles = _getFilteredArticles();
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.showSavedArticles ? 1 : 0;
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _checkConnectivity();
    _checkForUpdates();
    _loadViewMode();
    _loadSubscribedIds();
    // Reload from local storage when a cloud sync lands (sign-in restore,
    // cross-device changes). Guarded: tests run without the sync service.
    if (getIt.isRegistered<CloudSyncService>()) {
      _cloudSyncSub = getIt<CloudSyncService>().articlesRestored.listen((_) {
        if (mounted) unawaited(_loadData());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _autoRefreshEnabled = true;
        _connectivitySubscription?.resume();
        _armAutoRefresh();
        _loadSubscribedIds();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _autoRefreshEnabled = false;
        _autoRefreshTimer?.cancel();
        _autoRefreshTimer = null;
        _connectivitySubscription?.pause();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _loadViewMode() async {
    // SettingsNotifier has already been initialized and has the
    // persisted view mode in memory. Mirror it locally so toggling
    // updates both surfaces.
    final notifier = context.read<SettingsNotifier>();
    final mode = notifier.viewMode;
    if (!mounted) return;
    setState(() => _viewMode = mode);
  }

  Future<void> _toggleViewMode() async {
    final next = _viewMode == 'stack' ? 'continuous' : 'stack';
    setState(() => _viewMode = next);
    await context.read<SettingsNotifier>().setViewMode(next);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsNotifier>();
    final shouldRefresh =
        _autoRefreshTimer == null ||
        settings.autoRefresh != _lastAutoRefresh ||
        settings.refreshInterval != _lastRefreshInterval;
    if (shouldRefresh) {
      _setupAutoRefresh(settings);
    }
  }

  bool _lastAutoRefresh = false;
  int _lastRefreshInterval = 0;

  void _setupAutoRefresh(SettingsNotifier settings) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    _lastAutoRefresh = settings.autoRefresh;
    _lastRefreshInterval = settings.refreshInterval;
    if (!_autoRefreshEnabled ||
        !settings.autoRefresh ||
        settings.refreshInterval <= 0) {
      return;
    }
    // Single-shot schedule — does NOT keep firing while the app is
    // backgrounded. _restartAutoRefresh() is called from the
    // lifecycle observer's resume hook (see `_handleLifecycle`).
    _armAutoRefresh();
  }

  /// Schedule a single auto-refresh timer; used both at startup and on
  /// resume. We don't use `Timer.periodic` directly because the Dart
  /// isolate still has to drain the timer queue on resume — pausing
  /// the schedule lets us avoid spurious refreshes the moment the
  /// user comes back.
  void _armAutoRefresh() {
    _autoRefreshTimer?.cancel();
    final settings = context.read<SettingsNotifier>();
    if (!settings.autoRefresh || settings.refreshInterval <= 0) return;
    if (!_autoRefreshEnabled || !mounted) return;
    _autoRefreshTimer = Timer(
      Duration(minutes: settings.refreshInterval),
      _onAutoRefreshFired,
    );
  }

  void _onAutoRefreshFired() {
    if (!mounted) return;
    _refreshFeeds().whenComplete(() {
      if (mounted) _armAutoRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _cloudSyncSub?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    if (!mounted) return;
    setState(() {
      _isOnline = connectivityResult.contains(ConnectivityResult.none) == false;
    });

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (!mounted) return;
      setState(() {
        _isOnline = results.contains(ConnectivityResult.none) == false;
      });

      if (_isOnline && _articles.isNotEmpty) {
        _refreshFeeds();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _settingsService.getMaxArticles(),
        _storage.loadArticles(),
        _storage.loadSavedArticles(),
        _storage.loadLastRefreshTime(),
      ]);

      final maxArticles = results[0] as int;
      final articles = results[1] as List<Article>;
      final savedArticles = results[2] as List<Article>;
      final lastRefresh = results[3] as DateTime?;

      if (mounted) {
        setState(() {
          _articles = articles.take(maxArticles).toList();
          _displayedArticles = List.from(_articles);
          _savedArticles = savedArticles;
          _lastRefreshTime = lastRefresh;
        });
      }

      if (_isOnline) unawaited(_refreshFeeds());
    } catch (e) {
      unawaited(ErrorHandler.logError('Failed to load data', error: e));
      if (mounted) {
        setState(() {
          _articles = [];
          _displayedArticles = [];
          _savedArticles = [];
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    await Future<void>.delayed(Duration.zero); // yield to frame, then check
    if (!mounted) return;

    final updateInfo = await UpdateService.checkForUpdates(forceCheck: true);

    if (mounted && updateInfo != null) {
      await showUpdateDialog(context: context, updateInfo: updateInfo);
    }
  }

  Future<void> _refreshFeeds() async {
    // Single-flight + short minimum-interval guard. Connectivity
    // changes, manual taps, and auto-refresh can all trigger this
    // method back-to-back — coalesce into one network call per
    // ~10 seconds to avoid burn-on-mobile-radios.
    final existing = _refreshInFlight;
    if (existing != null) {
      debugPrint('[Feed] Refresh already in flight; awaiting result.');
      await existing;
      return;
    }
    final last = _lastRefreshAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 10) {
      debugPrint('[Feed] Refresh skipped (within 10s min interval).');
      return;
    }

    final completer = Completer<void>();
    _refreshInFlight = completer.future;
    try {
      await _performRefresh();
    } finally {
      _refreshInFlight = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _performRefresh() async {
    debugPrint('[Feed] Starting refresh...');
    await AnalyticsService.logFeedRefresh();

    final connectivityResult = await _connectivity.checkConnectivity();
    if (!mounted) return;
    debugPrint('[Feed] Connectivity result: $connectivityResult');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint('[Feed] Device is offline!');
      setState(() {
        _isLoading = false;
        _errorMessage = _l10n.offlineBanner;
      });
      return;
    }

    debugPrint('[Feed] Device is online, fetching articles...');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _articleRepository.fetchNewArticles();
      if (!mounted) return;
      final maxArticles = await _settingsService.getMaxArticles();
      if (!mounted) return;

      if (result.isSuccess) {
        final newArticles = (result.data ?? []).take(maxArticles).toList();
        debugPrint(
          '[Feed] Repository returned ${newArticles.length} new articles (max: $maxArticles)',
        );

        // Stamp AFTER success so a failed/offline attempt doesn't suppress a
        // retry for the 10s min-interval window (data-layer M5).
        _lastRefreshAt = DateTime.now();
        setState(() {
          _articles = newArticles;
          _displayedArticles = _getFilteredArticles();
          _lastRefreshTime = DateTime.now();
          _isLoading = false;
        });
        unawaited(_storage.saveLastRefreshTime(_lastRefreshTime));

        // Bump the editorial edition number on every successful refresh.
        if (mounted) {
          final next = await context.read<SettingsNotifier>().bumpEdition();
          EditionState.current = next;
          setState(() {});
        }

        debugPrint(
          '[Feed] Refresh complete. Total articles: ${_articles.length}',
        );
      } else {
        debugPrint('[Feed] ERROR: ${result.error}');
        setState(() {
          _errorMessage = result.error ?? _l10n.refreshFailedFallback;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Feed] ERROR during refresh: $e');
      unawaited(ErrorHandler.logError('Failed to refresh feeds', error: e));
      if (!mounted) return;
      setState(() {
        _errorMessage = ErrorHandler.getUserMessage(e);
        _isLoading = false;
      });
    }
  }

  void _onSwipeRight(int index) {
    if (index >= _displayedArticles.length) return;

    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    if (articleIndex == -1) return;

    setState(() {
      _savedArticles = List.from(_savedArticles);
      _articles[articleIndex].isSaved = true;

      if (!_savedArticles.any((a) => a.id == article.id)) {
        _savedArticles.insert(0, article);
      }

      // Flag-and-keep, not remove: the worker returns the full feed every
      // refresh and the merge keeps existing articles by id (dropping the
      // fresh copy). Removing the article left its isSaved flag un-persisted
      // and the merge re-added it unread+unsaved — saved articles reappeared
      // in triage after the next refresh. The feed filter excludes isSaved
      // (see _getFilteredArticles) so it leaves the stack by filtering, not
      // deletion.
      _displayedArticles = _getFilteredArticles();
    });

    // Row-level persist: a save touches two rows, not the whole cache.
    _articleRepository.syncFrom(_articles, _savedArticles);
    unawaited(_storage.saveArticle(_articles[articleIndex]));
    unawaited(_storage.saveSavedArticle(_articles[articleIndex]));
    _showSnackBar(_l10n.articleSavedSnack);
  }

  void _onSwipeLeft(int index) {
    if (index >= _displayedArticles.length) return;

    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    if (articleIndex == -1) return;

    setState(() {
      _articles[articleIndex].isRead = true;
      // Flag-and-keep, not remove: same reason as _onSwipeRight. The merge
      // in fetchNewArticles keeps existing articles by id; removing here
      // left isRead un-persisted and the worker re-added the article
      // unread. The feed filter hides isRead, so it leaves triage by
      // filtering, not deletion.
      _displayedArticles = _getFilteredArticles();
    });

    // Row-level persist: a read flag touches one row, not the whole cache.
    _articleRepository.syncFrom(_articles, _savedArticles);
    unawaited(_storage.saveArticle(_articles[articleIndex]));
    _showSnackBar(_l10n.articleMarkedReadSnack);
  }

  void _onToggleSave(Article article) {
    // Free users cap at AppConfig.freeSavedArticlesCap saved articles;
    // Pro users are unlimited. Un-saving is always allowed. ponytail:
    // no retroactive trim on Pro → Free downgrade; user keeps existing
    // saves and is blocked at the next attempt.
    final isSaving = !article.isSaved;
    if (isSaving) {
      final isPro = context.read<SettingsNotifier>().isPro;
      if (!isPro && _savedArticles.length >= AppConfig.freeSavedArticlesCap) {
        _showSnackBar(
          _l10n.freeSavedLimitReached(AppConfig.freeSavedArticlesCap),
        );
        return;
      }
    }

    setState(() {
      article.isSaved = !article.isSaved;

      if (article.isSaved) {
        if (!_savedArticles.any((a) => a.id == article.id)) {
          _savedArticles = [article, ..._savedArticles];
        }
        ErrorHandler.addBreadcrumb(
          'Article saved: ${article.title}',
          category: 'feed',
        );
      } else {
        _savedArticles = _savedArticles
            .where((a) => a.id != article.id)
            .toList();
        ErrorHandler.addBreadcrumb(
          'Article unsaved: ${article.title}',
          category: 'feed',
        );
      }
    });

    // Row-level persist: a toggle touches one feed row plus one saved row.
    _articleRepository.syncFrom(_articles, _savedArticles);
    unawaited(_storage.saveArticle(article));
    if (article.isSaved) {
      unawaited(_storage.saveSavedArticle(article));
    } else {
      unawaited(_storage.removeSavedArticle(article.id));
    }
  }

  void _onTapCard(int index) {
    if (index >= _displayedArticles.length) return;

    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    if (articleIndex == -1) return;
    if (articleIndex >= _articles.length) return;

    AnalyticsService.logArticleOpen(
      articleId: article.id,
      title: article.title,
    );
    ErrorHandler.addBreadcrumb(
      'Article opened: ${article.title}',
      category: 'navigation',
    );

    setState(() {
      _articles[articleIndex].isRead = true;
    });
    // Row-level persist: a read flag touches one row.
    _articleRepository.syncFrom(_articles, _savedArticles);
    unawaited(_storage.saveArticle(_articles[articleIndex]));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpandedArticleCard(
        article: _articles[articleIndex],
        onClose: () {
          // Persist fetchedFullContent set in the reader (data-layer L9).
          _articleRepository.syncFrom(_articles, _savedArticles);
          unawaited(_storage.saveArticle(_articles[articleIndex]));
          Navigator.pop(context);
        },
        onToggleSave: () {
          _onToggleSave(_articles[articleIndex]);
        },
      ),
    );
  }

  List<Article> _getFilteredArticles() {
    var articles = _selectedTab == 0
        ? _articles.where((a) => !a.isRead && !a.isSaved).toList()
        : _savedArticles;

    // Filter by subscribed sources (empty set = no filter applied yet).
    if (_subscribedIds.isNotEmpty) {
      articles = articles
          .where((a) => _subscribedIds.contains(a.sourceId))
          .toList();
    }

    // Drill-in from the Sources screen — lock to a single source.
    if (widget.sourceId != null) {
      articles = articles.where((a) => a.sourceId == widget.sourceId).toList();
    }

    if (_selectedFilter != 'All' && _selectedTab == 0) {
      final rssService = getIt<RssFeedService>();
      articles = articles.where((a) {
        final source = rssService.getSourceById(a.sourceId);
        return source?.category == _selectedFilter;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      articles = articles
          .where(
            (a) =>
                a.title.toLowerCase().contains(query) ||
                a.description.toLowerCase().contains(query) ||
                a.sourceName.toLowerCase().contains(query),
          )
          .toList();
    }

    return articles;
  }

  void _showSnackBar(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 2000),
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onInverseSurface,
          ),
        ),
        backgroundColor: colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        duration: duration,
        action: (actionLabel != null && onAction != null)
            ? SnackBarAction(
                label: actionLabel.toUpperCase(),
                textColor: colorScheme.primary,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  Future<void> _onMarkAllRead() async {
    if (!mounted || _unreadCount == 0) return;
    final result = await _articleRepository.markAllAsRead();
    if (!mounted) return;
    if (result.isFailure) {
      _showSnackBar(result.error ?? _l10n.markAllReadFailedSnack);
      return;
    }

    final snapshot = result.data ?? <String, bool>{};
    setState(() {
      _articles = _articles
          .map((a) => snapshot.containsKey(a.id) ? a.copyWith(isRead: true) : a)
          .toList();
      _displayedArticles = _getFilteredArticles();
    });

    final flipped = snapshot.length;
    _showSnackBar(
      _l10n.markedAsReadSnack(flipped),
      actionLabel: _l10n.undoAction,
      onAction: () => _undoMarkAllRead(snapshot),
      duration: const Duration(milliseconds: 4000),
    );
  }

  Future<void> _undoMarkAllRead(Map<String, bool> snapshot) async {
    final ids = snapshot.keys.toSet();
    if (ids.isEmpty) return;
    await _articleRepository.restoreReadState(snapshot);
    if (!mounted) return;
    setState(() {
      _articles = _articles
          .map((a) => ids.contains(a.id) ? a.copyWith(isRead: false) : a)
          .toList();
      _displayedArticles = _getFilteredArticles();
    });
    _showSnackBar(_l10n.restoredSnack);
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSearchEmpty = _isSearchActive && _searchQuery.isNotEmpty;
    final icon = isSearchEmpty
        ? Icons.search_off_rounded
        : _selectedTab == 0
        ? Icons.style_outlined
        : Icons.bookmark_outline_rounded;
    final title = isSearchEmpty
        ? _l10n.searchNoResultsTitle(_searchQuery)
        : _selectedTab == 0
        ? _l10n.emptyFeedTitle
        : _l10n.savedEmptyTitle;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppCardStyles.cardRadius),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Semantics(
              label: title,
              child: Icon(icon, size: 72, color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _errorMessage ?? title,
            style: _textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 22,
            ),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refreshFeeds,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_l10n.retryCta),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ] else if (isSearchEmpty) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _isSearchActive = false;
                  _displayedArticles = _getFilteredArticles();
                });
              },
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: Text(_l10n.clearSearchCta),
            ),
          ] else if (_selectedTab == 0 && _articles.isEmpty && !_isLoading) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _l10n.emptyFeedHint,
                textAlign: TextAlign.center,
                style: _textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    // Use shimmer skeleton instead of basic spinner
    return const FeedLoadingSkeleton();
  }

  Widget _buildCardView() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Refreshing banner when loading with cached content
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _isLoading && _articles.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    // Reskin: refreshing banner reads as a quiet groundElev
                    // strip + hairline + mono label, not an amber container.
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        AppCardStyles.badgeRadius,
                      ),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _l10n.refreshingBanner,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Card stack content
        Expanded(
          child: _displayedArticles.isEmpty && !_isLoading
              ? _buildEmptyState()
              : (_viewMode == 'stack'
                    ? CardStack(
                        articles: _displayedArticles,
                        onSwipeRight: _onSwipeRight,
                        onSwipeLeft: _onSwipeLeft,
                        onTap: _onTapCard,
                        emptyState: _buildEmptyState(),
                        isFilterActive: _selectedFilter != 'All',
                      )
                    : ContinuousFeedList(
                        articles: _displayedArticles,
                        onTap: _onTapCard,
                      )),
        ),
      ],
    );
  }

  Future<void> _refreshSavedArticles() async {
    final savedArticles = await _storage.loadSavedArticles();
    if (mounted) {
      setState(() {
        _savedArticles = savedArticles;
      });
    }
  }

  Widget _buildSavedArticlesView() {
    final colorScheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      strokeWidth: 2.5,
      onRefresh: _refreshSavedArticles,
      child: BentoSavedArticlesGrid(
        articles: _savedArticles,
        onTap: (index) => _onTapSavedArticle(index),
        onToggleSave: (index) => _onToggleSave(_savedArticles[index]),
        onDismiss: (index) => _removeSavedArticle(index),
        isEmpty: _savedArticles.isEmpty,
      ),
    );
  }

  void _removeSavedArticle(int index) {
    if (index >= _savedArticles.length) return;
    final article = _savedArticles[index];
    setState(() {
      article.isSaved = false;
      _savedArticles = _savedArticles.where((a) => a.id != article.id).toList();
    });
    // Row-level persist: un-save deletes one saved row and clears the
    // feed-row flag so the article can reappear in triage.
    _articleRepository.syncFrom(_articles, _savedArticles);
    unawaited(_storage.removeSavedArticle(article.id));
    unawaited(_storage.saveArticle(article));
    _showSnackBar(_l10n.articleRemovedSnack);
  }

  void _onTapSavedArticle(int index) {
    if (index >= _savedArticles.length) return;
    final article = _savedArticles[index];
    AnalyticsService.logArticleOpen(
      articleId: article.id,
      title: article.title,
    );
    setState(() {
      article.isRead = true;
    });
    // Row-level persist: a read flag on the saved copy touches one row.
    _articleRepository.syncFrom(_articles, _savedArticles);
    unawaited(_storage.saveSavedArticle(article));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpandedArticleCard(
        article: article,
        onClose: () => Navigator.pop(context),
        onToggleSave: () {
          _onToggleSave(article);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarTitleColor = colorScheme.onSurface;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? null : colorScheme.surface,
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.6, 1.0],
                    colors: [
                      ThemeProvider.darkGradientStart,
                      ThemeProvider.darkGradientMid,
                      ThemeProvider.darkGradientEnd,
                    ],
                  )
                : null,
          ),
        ),
        const GrainOverlay(),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: colorScheme.surface.withValues(
              alpha: isDark ? 0.0 : 1.0,
            ),
            elevation: isDark ? 0 : 2,
            shadowColor: isDark ? null : colorScheme.shadow,
            title: Text(
              _appBarTitle,
              style: _textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                color: appBarTitleColor,
              ),
            ),
            actions: [
              // Mark-all-read with undo.
              if (_selectedTab == 0)
                Semantics(
                  button: true,
                  label: _unreadCount > 0
                      ? _l10n.markAllReadSemantic(_unreadCount)
                      : _l10n.noUnreadToMark,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      onPressed: _unreadCount == 0
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _onMarkAllRead();
                            },
                      tooltip: _unreadCount > 0
                          ? _l10n.markAllAsReadAction
                          : _l10n.sourceUnsubscribedSubtitle,
                      icon: Icon(
                        _unreadCount == 0
                            ? Icons.done_all_rounded
                            : Icons.done_all_outlined,
                        color: appBarTitleColor,
                      ),
                    ),
                  ),
                ),
              // View-mode toggle (Stack / Continuous) — feed tab only.
              if (_selectedTab == 0)
                Semantics(
                  button: true,
                  label: _viewMode == 'stack'
                      ? _l10n.switchToContinuousTooltip
                      : _l10n.switchToStackTooltip,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _toggleViewMode();
                      },
                      tooltip: _viewMode == 'stack'
                          ? _l10n.continuousModeLabel
                          : _l10n.cardStackModeLabel,
                      icon: Icon(
                        _viewMode == 'stack'
                            ? Icons.view_agenda_outlined
                            : Icons.crop_square,
                        color: appBarTitleColor,
                      ),
                    ),
                  ),
                ),
              if (_selectedTab == 0 && _articles.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  // Reskin: unread count reads as a data chip, not a brand
                  // pill. groundElev fill + hairline + mono number; the amber
                  // dot earns the attention, not the whole container. Folio
                  // carries the same count on the feed tab; this chip shows
                  // on the source drill-in where Folio is hidden.
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(
                      AppCardStyles.badgeRadius,
                    ),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: '$_unreadCount unread articles',
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _unreadCount > 0
                                ? colorScheme.primary
                                : colorScheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_unreadCount',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: appBarTitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_selectedTab == 0)
                Semantics(
                  button: true,
                  label: _isLoading ? _l10n.loadingLabel : _l10n.refreshFeedsLabel,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              _refreshFeeds();
                            },
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  appBarTitleColor,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.refresh_rounded,
                              color: appBarTitleColor,
                            ),
                    ),
                  ),
                ),
              Semantics(
                button: true,
                label: _isSearchActive
                        ? _l10n.closeSearchLabel
                        : _l10n.searchArticlesLabel,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _isSearchActive = !_isSearchActive;
                        if (!_isSearchActive) {
                          _searchQuery = '';
                          _displayedArticles = _getFilteredArticles();
                        }
                      });
                    },
                    icon: Icon(
                      _isSearchActive
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      color: appBarTitleColor,
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: _l10n.moreOptionsLabel,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: appBarTitleColor),
                    color: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) async {
                      if (value == 'check_updates') {
                        final updateInfo = await UpdateService.checkForUpdates(
                          forceCheck: true,
                        );
                        if (context.mounted) {
                          if (updateInfo != null) {
                            await showUpdateDialog(
                              context: context,
                              updateInfo: updateInfo,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_l10n.upToDateMessage),
                              ),
                            );
                          }
                        }
                      } else if (value == 'settings') {
                        unawaited(
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          ),
                        );
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'check_updates',
                        child: Row(
                          children: [
                            const Icon(Icons.system_update),
                            const SizedBox(width: 12),
                            Text(_l10n.checkForUpdates),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            const Icon(Icons.settings),
                            const SizedBox(width: 12),
                            Text(_l10n.settingsTitle),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Folio Rule — signature masthead. Only on the feed tab,
                // and hidden on a source drill-in (its counts are feed-wide).
                if (_selectedTab == 0 && widget.sourceId == null)
                  Consumer<SettingsNotifier>(
                    builder: (context, settings, _) {
                      return FolioRule(
                        date: DateTime.now(),
                        edition: settings.edition,
                        articleCount: _displayedArticles.length,
                        unreadCount: _unreadCount,
                        isPro: settings.isPro,
                        // The amber dot doubles as the "mark all read"
                        // affordance — it ONLY exists when there is
                        // something unread, so tapping it is the
                        // fastest path to a clean slate. Stack mode
                        // and Continuous mode both use the same action.
                        onTapDot: _unreadCount > 0 ? _onMarkAllRead : null,
                      );
                    },
                  ),
                // Search bar - theme-aware styling
                if (_isSearchActive)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: TextField(
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: _l10n.searchHint,
                        hintStyle: _textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppCardStyles.badgeRadius,
                          ),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppCardStyles.badgeRadius,
                          ),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppCardStyles.badgeRadius,
                          ),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? Semantics(
                                button: true,
                                label: _l10n.clearSearchCta,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: appBarTitleColor,
                                  ),
                                  onPressed: () {
                                    _searchDebounceTimer?.cancel();
                                    setState(() {
                                      _searchQuery = '';
                                      _displayedArticles =
                                          _getFilteredArticles();
                                    });
                                  },
                                ),
                              )
                            : null,
                      ),
                      style: _textTheme.bodyLarge?.copyWith(
                        color: appBarTitleColor,
                        fontSize: 16,
                      ),
                      onChanged: (value) {
                        _searchDebounceTimer?.cancel();
                        _searchDebounceTimer = Timer(
                          const Duration(milliseconds: 250),
                          () {
                            if (mounted) {
                              setState(() {
                                _searchQuery = value;
                                _displayedArticles = _getFilteredArticles();
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),

                // Category filter chips for feeds tab — hidden on a source
                // drill-in, which is already a single-category view.
                if (_selectedTab == 0 &&
                    !_isSearchActive &&
                    widget.sourceId == null &&
                    (_articles.isNotEmpty || _isLoading)) ...[
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedFilter == category;

                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Semantics(
                            button: true,
                            label: 'Filter by $category',
                            selected: isSelected,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedFilter = category;
                                  _displayedArticles = _getFilteredArticles();
                                });
                              },
                              borderRadius: BorderRadius.circular(
                                AppCardStyles.badgeRadius,
                              ),
                              splashColor: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                              child: AnimatedContainer(
                                duration: AppCardStyles.quickDuration,
                                // §10 quality floor: ≥44dp touch target.
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                // Reskin: chip is not an amber fill. Selected =
                                // surface + paper text + amber underline; idle =
                                // transparent surface w/ hairline. Amber is the
                                // attention color, not a neutral accent.
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.surfaceContainerHighest
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppCardStyles.badgeRadius,
                                  ),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isSelected
                                          ? colorScheme.primary
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  category,
                                  style: _textTheme.labelLarge?.copyWith(
                                    color: isSelected
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Search results indicator
                if (_isSearchActive && _searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                          Text(
                            _l10n.searchResultsCount(
                              _displayedArticles.length,
                              _searchQuery,
                            ),
                          style: _textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Offline indicator
                if (!_isOnline && _selectedTab == 0)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(
                        AppCardStyles.badgeRadius,
                      ),
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 16,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Offline — showing cached content',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!_isOnline) const SizedBox(height: 8),

                // Content
                Expanded(
                  child: RefreshIndicator(
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surface,
                    strokeWidth: 2.5,
                    onRefresh: _isLoading
                        ? () async {}
                        : () async {
                            await _refreshFeeds();
                          },
                    child: _isLoading && _articles.isEmpty
                        ? _buildLoadingState()
                        : _selectedTab == 0
                        ? _buildCardView()
                        : _buildSavedArticlesView(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
