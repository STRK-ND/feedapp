import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../providers/version_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/card_stack.dart';
import '../widgets/expanded_article_card.dart';
import '../widgets/update_dialog.dart';
import '../widgets/bento_saved_articles.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/error_handler.dart';
import '../services/rss_feed_service.dart';
import '../di/service_locator.dart';

/// Main RSS Feed Screen
/// [showSavedArticles] - when true, displays saved articles instead of feed
class RssFeedScreen extends StatefulWidget {
  final bool showSavedArticles;

  const RssFeedScreen({super.key, this.showSavedArticles = false});

  @override
  State<RssFeedScreen> createState() => _RssFeedScreenState();
}

class _RssFeedScreenState extends State<RssFeedScreen>
    with TickerProviderStateMixin {
  List<Article> _articles = [];
  List<Article> _savedArticles = [];
  List<Article> _displayedArticles = [];
  String _selectedFilter = 'All';
  ViewMode _viewMode = ViewMode.cards;
  int _selectedTab = 0;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastRefreshTime;
  bool _isOnline = true;
  bool _isSearchActive = false;
  String _searchQuery = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  late AnimationController _fabController;
  late AnimationController _staggerController;

  final List<String> _categories = AppConfig.categories;
  final StorageService _storage = StorageService();
  final ArticleRepository _articleRepository = ArticleRepository();

  int get _unreadCount => _articles.where((a) => !a.isRead).length;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.showSavedArticles ? 1 : 0;
    _loadData();
    _loadViewMode();
    _checkConnectivity();
    _checkForUpdates();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fabController.forward();
  }

  @override
  void didUpdateWidget(RssFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reload if transitioning TO saved view (was not saved view before)
    if (!oldWidget.showSavedArticles && widget.showSavedArticles) {
      _loadSavedArticlesOnly();
    }
  }

  Future<void> _loadSavedArticlesOnly() async {
    final savedArticles = await _storage.loadSavedArticles();
    if (mounted) {
      setState(() {
        _savedArticles = savedArticles;
      });
    }
  }

  @override
  void dispose() {
    // Memory leak fix: Cancel subscription explicitly
    _connectivitySubscription?.cancel();
    _fabController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult.contains(ConnectivityResult.none) == false;
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      setState(() {
        _isOnline = results.contains(ConnectivityResult.none) == false;
      });

      // Automatically refresh when coming back online
      if (_isOnline && _articles.isNotEmpty) {
        _refreshFeeds();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final articles = await _storage.loadArticles();
      final savedArticles = await _storage.loadSavedArticles();
      final lastRefresh = await _storage.loadLastRefreshTime();

      if (mounted) {
        setState(() {
          _articles = articles;
          _displayedArticles = List.from(_articles);
          _savedArticles = savedArticles;
          _lastRefreshTime = lastRefresh;
        });
      }

      _staggerController.forward();
      _refreshFeeds();
    } catch (e) {
      ErrorHandler.logError('Failed to load data', error: e);
      // Continue with empty state
      if (mounted) {
        setState(() {
          _articles = [];
          _displayedArticles = [];
          _savedArticles = [];
        });
      }
    }
  }

  Future<void> _loadViewMode() async {
    final viewModeString = await _storage.loadViewMode();
    if (viewModeString != null && mounted) {
      setState(() {
        _viewMode = viewModeString == 'list' ? ViewMode.list : ViewMode.cards;
      });
    }
  }

  Future<void> _saveViewMode() async {
    await _storage.saveViewMode(_viewMode == ViewMode.list ? 'list' : 'cards');
  }

  Future<void> _checkForUpdates() async {
    // Delay check to avoid showing on first launch
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final updateInfo = await UpdateService.checkForUpdates(forceCheck: true);

    if (mounted && updateInfo != null) {
      if (context.mounted) {
        showUpdateDialog(context: context, updateInfo: updateInfo);
      }
    }
  }

  Future<void> _saveArticles() async {
    try {
      await _storage.saveArticles(_articles);
      await _storage.saveSavedArticles(_savedArticles);
      await _storage.saveLastRefreshTime(_lastRefreshTime);
    } catch (e) {
      ErrorHandler.logError('Failed to save articles', error: e);
    }
  }

  Future<void> _refreshFeeds() async {
    debugPrint('[Feed] Starting refresh...');
  await AnalyticsService.logFeedRefresh();

    // Check if offline
    final connectivityResult = await Connectivity().checkConnectivity();
    debugPrint('[Feed] Connectivity result: $connectivityResult');

    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint('[Feed] Device is offline!');
      setState(() {
        _isLoading = false;
        _errorMessage = 'You are offline. Showing cached content.';
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

      if (result.isSuccess) {
        final newArticles = result.data ?? [];
        debugPrint('[Feed] Repository returned ${newArticles.length} new articles');

        setState(() {
          _articles = newArticles;
          _displayedArticles = _getFilteredArticles();
          _lastRefreshTime = DateTime.now();
          _isLoading = false;
        });

        debugPrint('[Feed] Refresh complete. Total articles: ${_articles.length}');
      } else {
        debugPrint('[Feed] ERROR: ${result.error}');
        setState(() {
          _errorMessage = result.error ?? 'Failed to refresh feeds';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[Feed] ERROR during refresh: $e');
      ErrorHandler.logError('Failed to refresh feeds', error: e);
      setState(() {
        _errorMessage = ErrorHandler.getUserMessage(e);
        _isLoading = false;
      });
    }
  }

  void _onSwipeRight(int index) {
    if (index >= _displayedArticles.length) {
      print('Warning: Invalid index in _onSwipeRight: $index');
      return;
    }

    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    if (articleIndex == -1) {
      print('Warning: Article not found in main list: ${article.id}');
      return;
    }

    setState(() {
      // Create new list to trigger rebuild
      _savedArticles = List.from(_savedArticles);
      _articles[articleIndex].isSaved = true;

      if (!_savedArticles.any((a) => a.id == article.id)) {
        _savedArticles.insert(0, article);
      }

      _articles.removeAt(articleIndex);
      _displayedArticles = _getFilteredArticles();
    });

    _saveArticles();

    _showSnackBar('Article saved', AppColors.success);
  }

  void _onSwipeLeft(int index) {
    if (index >= _displayedArticles.length) {
      print('Warning: Invalid index in _onSwipeLeft: $index');
      return;
    }

    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    if (articleIndex == -1) {
      print('Warning: Article not found in main list: ${article.id}');
      return;
    }

    setState(() {
      _articles[articleIndex].isRead = true;
      _articles.removeAt(articleIndex);
      _displayedArticles = _getFilteredArticles();
    });

    _saveArticles();

    _showSnackBar('Article marked as read', AppColors.textSecondary);
  }

  void _onToggleSave(Article article) {
    setState(() {
      article.isSaved = !article.isSaved;

      if (article.isSaved) {
        if (!_savedArticles.any((a) => a.id == article.id)) {
          _savedArticles = [article, ..._savedArticles];
        }
      } else {
        _savedArticles = _savedArticles.where((a) => a.id != article.id).toList();
      }
    });

    _saveArticles();

    setState(() {
      if (_selectedTab == 1) {
        _savedArticles = _savedArticles.where((a) => a.isSaved).toList();
      }
    });
  }

  void _onTapCard(int index) {
    if (index >= _displayedArticles.length) {
      print('Warning: Invalid index in _onTapCard: $index');
      return;
    }

    final article = _displayedArticles[index];
    final articleIndex = _articles.indexWhere((a) => a.id == article.id);

    if (articleIndex == -1) {
      print('Warning: Article not found in main list: ${article.id}');
      return;
    }
    AnalyticsService.logArticleOpen(articleId: article.id, title: article.title);

    if (articleIndex >= _articles.length) {
      print('Warning: Article index out of bounds: $articleIndex');
      return;
    }

    setState(() {
      _articles[articleIndex].isRead = true;
    });
    _saveArticles();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExpandedArticleCard(
        article: _articles[articleIndex],
        onClose: () => Navigator.pop(context),
        onToggleSave: () {
          _onToggleSave(_articles[articleIndex]);
        },
      ),
    );
  }

  List<Article> _getFilteredArticles() {
    var articles = _selectedTab == 0 ? _articles.where((a) => !a.isRead).toList() : _savedArticles;

    if (_selectedFilter != 'All' && _selectedTab == 0) {
      articles = articles.where((a) {
        final source = getIt<RssFeedService>().getSourceById(a.sourceId);
        return source?.category == _selectedFilter;
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      articles = articles.where((a) =>
        a.title.toLowerCase().contains(query) ||
        a.description.toLowerCase().contains(query) ||
        a.sourceName.toLowerCase().contains(query)
      ).toList();
    }

    return articles;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: color.withValues(alpha:  0.2),
            width: 1,
          ),
        ),
        elevation: 8,
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  Widget _buildEmptyState() {
    final icon = _selectedTab == 0
        ? (_viewMode == ViewMode.cards ? Icons.style_outlined : Icons.inbox_outlined)
        : Icons.bookmark_outline_rounded;

    final title = _selectedTab == 0
        ? (_viewMode == ViewMode.cards ? 'No articles' : 'No articles yet')
        : 'No saved articles';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.divider.withValues(alpha:  0.3),
                width: 1,
              ),
            ),
            child: Semantics(
              label: title,
              child: Icon(
                icon,
                size: 72,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _errorMessage ?? title,
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _refreshFeeds,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          button: true,
                          label: 'Retry loading feeds',
                          child: Icon(Icons.refresh_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurface, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ] else if (_selectedTab == 0 && _articles.isEmpty && !_isLoading) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Tap the refresh button to load articles',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'Loading feeds',
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading feeds...',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardView() {
    return CardStack(
      articles: _displayedArticles,
      onSwipeRight: _onSwipeRight,
      onSwipeLeft: _onSwipeLeft,
      onTap: _onTapCard,
      emptyState: _buildEmptyState(),
      isFilterActive: _selectedFilter != 'All',
    );
  }

  Widget _buildListView() {
    if (_displayedArticles.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _displayedArticles.length,
      itemBuilder: (context, index) {
        final article = _displayedArticles[index];
        final source = getIt<RssFeedService>().getSourceById(article.sourceId) ??
            RssFeedService.predefinedSources.first;
        final sourceColor = source.color;

        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final delay = index * 0.04;
            final animation = CurvedAnimation(
              parent: _staggerController,
              curve: Interval(
                delay.clamp(0.0, 0.8),
                (delay + 0.15).clamp(0.1, 1.0),
                curve: Curves.easeOutQuart,
              ),
            );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Semantics(
            button: true,
            label: '${article.title}, from ${article.sourceName}, published ${Helpers.formatTimeAgo(article.pubDate)}',
            child: GestureDetector(
              onTap: () => _onTapCard(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: sourceColor.withValues(alpha:  0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha:  0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha:  0.5),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: sourceColor.withValues(alpha:  0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                label: source.name,
                                child: Icon(source.icon, size: 14, color: sourceColor),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                source.name,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sourceColor,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.title,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  height: 1.3,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                article.description,
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                  letterSpacing: 0.05,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Semantics(
                                    label: 'Published ${Helpers.formatTimeAgo(article.pubDate)}',
                                    child: Icon(Icons.schedule_outlined,
                                        size: 12, color: AppColors.textTertiary),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    Helpers.formatTimeAgo(article.pubDate),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSavedArticlesView() {
    return BentoSavedArticlesGrid(
      articles: _savedArticles,
      onTap: (index) => _onTapSavedArticle(index),
      onToggleSave: (index) => _onToggleSave(_savedArticles[index]),
      onDismiss: (index) => _removeSavedArticle(index),
      isEmpty: _savedArticles.isEmpty,
    );
  }

  void _removeSavedArticle(int index) {
    if (index >= _savedArticles.length) return;
    final article = _savedArticles[index];
    setState(() {
      article.isSaved = false;
      _savedArticles = _savedArticles.where((a) => a.id != article.id).toList();
    });
    _saveArticles();
    _showSnackBar('Article removed from saved', AppColors.textSecondary);
  }

  void _onTapSavedArticle(int index) {
    if (index >= _savedArticles.length) return;
    final article = _savedArticles[index];
    AnalyticsService.logArticleOpen(articleId: article.id, title: article.title);
    setState(() {
      article.isRead = true;
    });
    _saveArticles();

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


  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _buildSettingsSection('About', [
          _buildSettingsItem(
            icon: Icons.info_outline_rounded,
            title: 'Version',
            subtitle: _buildVersionWidget(),
            trailing: null,
            onTap: null,
          ),
        ]),
        const SizedBox(height: 20),
        _buildSettingsSection('Appearance', [
          _buildSettingsItem(
            icon: Icons.view_column_outlined,
            title: 'View Mode',
            subtitle: Text(_viewMode == ViewMode.cards ? 'Card View' : 'List View'),
            trailing: Icon(
              _viewMode == ViewMode.cards ? Icons.style_outlined : Icons.list_outlined,
              color: AppColors.textTertiary,
            ),
            onTap: () {
              setState(() {
                _viewMode = _viewMode == ViewMode.cards
                    ? ViewMode.list
                    : ViewMode.cards;
              });
              _saveViewMode();
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildSettingsSection('Data', [
          _buildSettingsItem(
            icon: Icons.bookmark_outline_rounded,
            title: 'Saved Articles',
            subtitle: Text('${_savedArticles.length} articles saved'),
            trailing: null,
            onTap: null,
          ),
        ]),
        const SizedBox(height: 20),
        _buildSettingsSection('Support', [
          _buildSettingsItem(
            icon: Icons.refresh_rounded,
            title: 'Refresh Feeds',
            subtitle: const Text('Pull down to refresh or tap here'),
            trailing: null,
            onTap: _isLoading ? null : _refreshFeeds,
          ),
        ]),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha:  0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    Widget? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.divider.withValues(alpha:  0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (subtitle != null) ...[
                      DefaultTextStyle(
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        child: subtitle,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
              if (onTap != null) ...[
                if (trailing == null) const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build version widget that dynamically fetches from VersionProvider
  Widget _buildVersionWidget() {
    return FutureBuilder<String>(
      future: VersionProvider.getVersionWithBuild(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Text(snapshot.data!);
        }
        return const Text('Loading...');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? null : colorScheme.surface,
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.6, 1.0],
                colors: [
                  Color(0xFF1A1B4D),
                  Color(0xFF2D2F73),
                  Color(0xFF4A3B5C),
                ],
              )
            : null,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _selectedTab == 0
                ? 'Curated Feeds'
                : _selectedTab == 1
                    ? 'Saved'
                    : 'Settings',
            style: GoogleFonts.playfairDisplay(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            if (_selectedTab == 0 && _articles.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:  0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha:  0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Semantics(
                      label: '$_unreadCount unread articles',
                      child: Icon(
                        Icons.article_outlined,
                        size: 18,
                        color: Colors.white.withValues(alpha:  0.9),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_unreadCount',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedTab == 0)
              Semantics(
                button: true,
                label: _isLoading ? 'Loading' : 'Refresh feeds',
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    onPressed: _isLoading ? null : _refreshFeeds,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, color: Colors.white),
                  ),
                ),
              ),
            Semantics(
              button: true,
              label: _isSearchActive ? 'Close search' : 'Search articles',
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _isSearchActive = !_isSearchActive;
                      if (!_isSearchActive) {
                        _searchQuery = '';
                        _displayedArticles = _getFilteredArticles();
                      }
                    });
                  },
                  icon: Icon(
                    _isSearchActive ? Icons.close_rounded : Icons.search_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'More options',
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) async {
                    if (value == 'check_updates') {
                      final updateInfo = await UpdateService.checkForUpdates(forceCheck: true);
                      if (context.mounted) {
                        if (updateInfo != null) {
                          showUpdateDialog(context: context, updateInfo: updateInfo);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You\'re using the latest version!')),
                          );
                        }
                      }
                    } else if (value == 'toggle_view') {
                      setState(() {
                        _viewMode = _viewMode == ViewMode.cards ? ViewMode.list : ViewMode.cards;
                      });
                      _saveViewMode();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'check_updates',
                      child: Row(
                        children: [
                          Icon(Icons.system_update),
                          SizedBox(width: 12),
                          Text('Check for updates'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_view',
                      child: Row(
                        children: [
                          Icon(_viewMode == ViewMode.cards ? Icons.view_list : Icons.grid_view),
                          const SizedBox(width: 12),
                          Text(_viewMode == ViewMode.cards ? 'Switch to List View' : 'Switch to Card View'),
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
              // Search bar
              if (_isSearchActive)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search articles, sources, or content...',
                      hintStyle: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha:  0.7),
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha:  0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha:  0.2),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha:  0.2),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.accent,
                          width: 2,
                        ),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? Semantics(
                              button: true,
                              label: 'Clear search',
                              child: IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _displayedArticles = _getFilteredArticles();
                                  });
                                },
                              ),
                            )
                          : null,
                    ),
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _displayedArticles = _getFilteredArticles();
                      });
                    },
                  ),
                ),

              // Category filter chips for feeds tab (hidden when search is active)
              if (_selectedTab == 0 && !_isSearchActive && (_articles.isNotEmpty || _isLoading == false)) ...[
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
                      final color = category == 'All'
                          ? Colors.white
                          : getCategoryColor(category);

                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Semantics(
                          button: true,
                          label: 'Filter by $category',
                          selected: isSelected,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedFilter = category;
                                _displayedArticles = _getFilteredArticles();
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            splashColor: Colors.white.withValues(alpha:  0.1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? color : Colors.white.withValues(alpha:  0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : Colors.white.withValues(alpha:  0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                category,
                                style: GoogleFonts.dmSans(
                                  color: Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 16, color: Colors.white.withValues(alpha:  0.7)),
                      const SizedBox(width: 8),
                      Text(
                        '${_displayedArticles.length} result${_displayedArticles.length != 1 ? 's' : ''} for "$_searchQuery"',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha:  0.7),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha:  0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha:  0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline - Showing cached content',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_isOnline) const SizedBox(height: 8),

              // Content
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : RefreshIndicator(
                        color: AppColors.accent,
                        backgroundColor: AppColors.surface,
                        strokeWidth: 2.5,
                        onRefresh: _isLoading ? () async {} : () async {
                          await _refreshFeeds();
                        },
                        child: _selectedTab == 0
                            ? (_viewMode == ViewMode.cards
                                ? _buildCardView()
                                : _buildListView())
                            : _selectedTab == 1
                                ? _buildSavedArticlesView()
                                : _buildSettingsView(),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: _selectedTab == 0 && !_isSearchActive
            ? Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:  0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Semantics(
                  button: true,
                  label: _viewMode == ViewMode.cards ? 'Switch to list view' : 'Switch to card view',
                  child: FloatingActionButton.small(
                    heroTag: 'view_mode',
                    onPressed: () {
                      setState(() {
                        _viewMode = _viewMode == ViewMode.cards
                            ? ViewMode.list
                            : ViewMode.cards;
                      });
                      _saveViewMode();
                    },
                    backgroundColor: AppColors.surface,
                    elevation: 0,
                    child: Icon(
                      _viewMode == ViewMode.cards
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
              ),
    );
  }

  Widget _buildBottomAppBar() {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:  0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.rss_feed_rounded,
                  label: 'Feeds',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.bookmark_rounded,
                  label: 'Saved',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: isSelected,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedTab = index;
              if (index == 1) {
                _displayedArticles = List.from(_savedArticles);
              } else if (index == 0) {
                _displayedArticles = _getFilteredArticles();
              }
              // Settings tab (index 2) doesn't need displayed articles
            });
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha:  0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? AppColors.primary : AppColors.textTertiary,
                          size: 22,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              label,
                              style: GoogleFonts.dmSans(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                letterSpacing: 0.1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
