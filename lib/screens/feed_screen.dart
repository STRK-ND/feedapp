import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/article.dart';
import '../models/rss_source.dart';
import '../services/rss_feed_service.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../services/version_provider.dart';
import '../widgets/card_stack.dart';
import '../widgets/expanded_article_card.dart';
import '../widgets/update_dialog.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/error_handler.dart';

/// Horizontal scrollable row with consistent spacing
class SingleChildScrollableRow extends StatelessWidget {
  final List<Widget> children;
  final Axis scrollDirection;
  final double spacing;
  final EdgeInsets? padding;
  final ScrollController? controller;

  const SingleChildScrollableRow({
    super.key,
    required this.children,
    this.scrollDirection = Axis.horizontal,
    this.spacing = 0,
    this.padding,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: scrollDirection,
      controller: controller,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
      child: scrollDirection == Axis.horizontal
          ? Row(children: _buildChildrenWithSpacing())
          : Column(children: _buildChildrenWithSpacing()),
    );
  }

  List<Widget> _buildChildrenWithSpacing() {
    final result = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }
    return result;
  }
}

/// Main RSS Feed Screen
class RssFeedScreen extends StatefulWidget {
  const RssFeedScreen({super.key});

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

  int get _unreadCount => _articles.where((a) => !a.isRead).length;

  @override
  void initState() {
    super.initState();
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
      final newArticles = await RssFeedService.fetchAllArticles();
      debugPrint('[Feed] Received ${newArticles.length} new articles');

      final existingArticleIds = _articles.map((a) => a.id).toSet();
      final articlesToAdd = newArticles.where((a) => !existingArticleIds.contains(a.id)).toList();
      debugPrint('[Feed] Adding ${articlesToAdd.length} articles (existing count: ${_articles.length})');

      setState(() {
        // Keep existing articles, add new ones, then sort
        _articles.addAll(articlesToAdd);
        _articles.sort((a, b) => b.pubDate.compareTo(a.pubDate));
        _displayedArticles = _getFilteredArticles();
        _lastRefreshTime = DateTime.now();
        _isLoading = false;
      });

      debugPrint('[Feed] Refresh complete. Total articles: ${_articles.length}');

      await _saveArticles();
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
      _articles[articleIndex].isSaved = true;

      if (!_savedArticles.any((a) => a.id == article.id)) {
        _savedArticles.insert(0, article);
      }

      _articles.removeAt(articleIndex);
      _displayedArticles = _getFilteredArticles();
    });

    _saveArticles();
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
          _savedArticles.insert(0, article);
        }
      } else {
        _savedArticles.removeWhere((a) => a.id == article.id);
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
      backgroundColor: AppColors.surface,
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
        final source = RssFeedService.getSourceById(a.sourceId);
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
          style: GoogleFonts.lexend(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  Widget _buildEmptyState() {
    final icon = _selectedTab == 0
        ? (_viewMode == ViewMode.cards ? Icons.auto_awesome_motion_outlined : Icons.inbox_outlined)
        : Icons.bookmark_border_outlined;

    final title = _selectedTab == 0
        ? (_viewMode == ViewMode.cards ? 'No articles to show' : 'No articles yet')
        : 'No saved articles';

    final subtitle = _selectedTab == 0 && _selectedTab == 0 && _articles.isEmpty && !_isLoading
        ? 'Pull down to refresh or tap the button below'
        : _selectedTab == 1
            ? 'Swipe right on articles to save them for later'
            : 'Your saved articles will appear here';

    return Center(
      child: GlassContainer(
        borderRadius: 20,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon container
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Semantics(
                label: title,
                child: Icon(
                  icon,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              _errorMessage ?? title,
              style: GoogleFonts.lexend(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _errorMessage != null ? _errorMessage! : subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              _buildStyledButton(
                label: 'Try Again',
                onPressed: _refreshFeeds,
                icon: Icons.refresh_rounded,
              ),
            ],
            if (_errorMessage == null && _selectedTab == 0 && _articles.isEmpty && !_isLoading) ...[
              const SizedBox(height: 24),
              _buildStyledButton(
                label: 'Load Articles',
                onPressed: _refreshFeeds,
                icon: Icons.download_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStyledButton({
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textOnPrimary),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.lexend(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textOnPrimary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String category,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: 'Filter by $category',
      selected: isSelected,
      child: AnimatedContainer(
        duration: Helpers.getAnimationDuration(
          const Duration(milliseconds: 200),
          reducedDuration: const Duration(milliseconds: 100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.8) : AppColors.border,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          category,
          style: GoogleFonts.lexend(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
        ),
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
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading feeds...',
            style: GoogleFonts.lexend(
              fontSize: 16,
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

    // Cache source data for performance - avoid repeated lookups
    final sources = RssFeedService.predefinedSources;
    final sourceMap = {for (var s in sources) s.id: s};

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _displayedArticles.length,
      itemBuilder: (context, index) {
        final article = _displayedArticles[index];
        // Use cached map for O(1) lookup instead of O(n)
        final source = sourceMap[article.sourceId] ??
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
          child: _buildListItem(article, sourceColor, source),
        );
      },
    );
  }

  Widget _buildListItem(Article article, Color sourceColor, RssSource source) {
    return Semantics(
      button: true,
      label: '${article.title}, from ${source.name}, published ${Helpers.formatTimeAgo(article.pubDate)}',
      child: GestureDetector(
        key: ValueKey('article_${article.id}'),
        onTap: () => _onTapCard(_displayedArticles.indexOf(article)),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowSmall,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source badge
                Container(
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    border: Border.all(
                      color: sourceColor.withValues(alpha: 0.12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(source.icon, size: 14, color: sourceColor),
                      const SizedBox(width: 8),
                      Text(
                        source.name,
                        style: GoogleFonts.lexend(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sourceColor,
                          letterSpacing: 0.1,
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
                        style: GoogleFonts.lexend(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.4,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.description,
                        style: GoogleFonts.lexend(
                          fontSize: 13,
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
                          Icon(Icons.access_time_rounded, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 6),
                          Text(
                            Helpers.formatTimeAgo(article.pubDate),
                            style: GoogleFonts.lexend(
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
    );
  }

  Widget _buildSavedArticlesView() {
    if (_savedArticles.isEmpty) {
      return Center(
        child: GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.secondarySurface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Semantics(
                  label: 'No saved articles',
                  child: Icon(
                    Icons.bookmark_border_outlined,
                    size: 48,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'No saved articles yet',
                style: GoogleFonts.lexend(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Swipe right on articles to save them for later reading',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.lexend(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: _savedArticles.length,
      itemBuilder: (context, index) {
        final article = _savedArticles[index];
        final source = RssFeedService.getSourceById(article.sourceId) ??
            RssFeedService.predefinedSources.first;
        final sourceColor = source.color;

        return Dismissible(
          key: ValueKey(article.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            _onToggleSave(article);
          },
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              border: Border.all(color: AppColors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowSmall,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: sourceColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                      border: Border.all(
                        color: sourceColor.withValues(alpha: 0.12),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(source.icon, size: 14, color: sourceColor),
                        const SizedBox(width: 8),
                        Text(
                          source.name,
                          style: GoogleFonts.lexend(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sourceColor,
                            letterSpacing: 0.1,
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
                          style: GoogleFonts.lexend(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.4,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article.description,
                          style: GoogleFonts.lexend(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                            letterSpacing: 0.05,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: article.isSaved ? 'Remove from saved' : 'Save article',
                    child: IconButton(
                      icon: Icon(
                        article.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        color: article.isSaved ? AppColors.secondary : AppColors.textTertiary,
                      ),
                      onPressed: () => _onToggleSave(article),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: GoogleFonts.lexend(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
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
                      style: GoogleFonts.lexend(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle(
                        style: GoogleFonts.lexend(
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Text(
              _selectedTab == 0
                  ? 'Curated Feeds'
                  : _selectedTab == 1
                      ? 'Saved'
                      : 'Settings',
              style: GoogleFonts.lexend(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            if (_selectedTab == 0 && _articles.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_motion_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_unreadCount',
                      style: GoogleFonts.lexend(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_selectedTab == 0)
            Semantics(
              button: true,
              label: _isLoading ? 'Loading' : 'Refresh feeds',
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  onPressed: _isLoading ? null : _refreshFeeds,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, color: AppColors.primary),
                ),
              ),
            ),
          Semantics(
            button: true,
            label: _isSearchActive ? 'Close search' : 'Search articles',
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
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
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'More options',
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                surfaceTintColor: AppColors.surface,
                onSelected: (value) async {
                  if (value == 'check_updates') {
                    final updateInfo = await UpdateService.checkForUpdates(forceCheck: true);
                    if (context.mounted) {
                      if (updateInfo != null) {
                        showUpdateDialog(context: context, updateInfo: updateInfo);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("You're using the latest version!"),
                              backgroundColor: AppColors.surface,
                            ),
                          );
                        }
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
                  PopupMenuItem(
                    value: 'check_updates',
                    child: Row(
                      children: [
                        const Icon(Icons.system_update, color: AppColors.textPrimary),
                        const SizedBox(width: 12),
                        Text(
                          'Check for updates',
                          style: GoogleFonts.lexend(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_view',
                    child: Row(
                      children: [
                        Icon(
                          _viewMode == ViewMode.cards ? Icons.view_list : Icons.grid_view,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _viewMode == ViewMode.cards ? 'List View' : 'Card View',
                          style: GoogleFonts.lexend(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          if (_isSearchActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search articles, sources, or content...',
                  hintStyle: GoogleFonts.lexend(
                    color: AppColors.textTertiary,
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? Semantics(
                          button: true,
                          label: 'Clear search',
                          child: IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
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
                style: GoogleFonts.lexend(
                  color: AppColors.textPrimary,
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

          // Category filter for feeds tab
          if (_selectedTab == 0 && !_isSearchActive && (_articles.isNotEmpty || _isLoading == false))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollableRow(
                scrollDirection: Axis.horizontal,
                spacing: 10,
                children: _categories.map((category) {
                  final isSelected = _selectedFilter == category;
                  final color = category == 'All' ? AppColors.primary : getCategoryColor(category);

                  return _buildCategoryChip(
                    category: category,
                    isSelected: isSelected,
                    color: color,
                    onTap: () {
                      setState(() {
                        _selectedFilter = category;
                        _displayedArticles = _getFilteredArticles();
                      });
                    },
                  );
                }).toList(),
              ),
            ),

          // Search results indicator
          if (_isSearchActive && _searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Text(
                    '${_displayedArticles.length} result${_displayedArticles.length != 1 ? 's' : ''} for "$_searchQuery"',
                    style: GoogleFonts.lexend(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Offline indicator
          if (!_isOnline && _selectedTab == 0)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.cloud_off_rounded, size: 16, color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Offline - Showing cached content',
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : RefreshIndicator(
                    color: AppColors.primary,
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
      floatingActionButton: _selectedTab == 0 && !_isSearchActive
          ? FloatingActionButton.small(
              heroTag: 'view_mode',
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == ViewMode.cards
                      ? ViewMode.list
                      : ViewMode.cards;
                });
                _saveViewMode();
              },
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _viewMode == ViewMode.cards ? Icons.view_list_rounded : Icons.grid_view_rounded,
                size: 20,
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 0,
        indicatorColor: AppColors.primarySurface,
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTab = index;
            if (index == 1) {
              _displayedArticles = List.from(_savedArticles);
            } else if (index == 0) {
              _displayedArticles = _getFilteredArticles();
            }
          });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.rss_feed_outlined,
              color: _selectedTab == 0 ? AppColors.primary : AppColors.textTertiary,
            ),
            selectedIcon: Icon(
              Icons.rss_feed_rounded,
              color: AppColors.primary,
            ),
            label: 'Feeds',
          ),
          NavigationDestination(
            icon: Icon(
              _savedArticles.isEmpty ? Icons.bookmark_border_outlined : Icons.bookmark_outline,
              color: _selectedTab == 1 ? AppColors.primary : AppColors.textTertiary,
            ),
            selectedIcon: Icon(
              Icons.bookmark_rounded,
              color: AppColors.secondary,
            ),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
              color: _selectedTab == 2 ? AppColors.primary : AppColors.textTertiary,
            ),
            selectedIcon: Icon(
              Icons.settings_rounded,
              color: AppColors.primary,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
