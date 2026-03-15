import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../utils/error_handler.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// Feed state for UI consumption
class FeedState {
  final List<Article> articles;
  final List<Article> savedArticles;
  final List<Article> displayedArticles;
  final String selectedCategory;
  final ViewMode viewMode;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final DateTime? lastRefreshTime;
  final int unreadCount;
  final String? searchQuery;
  final bool isSearchActive;

  const FeedState({
    this.articles = const [],
    this.savedArticles = const [],
    this.displayedArticles = const [],
    this.selectedCategory = 'All',
    this.viewMode = ViewMode.cards,
    this.isLoading = false,
    this.isRefreshing = false,
    this.errorMessage,
    this.lastRefreshTime,
    this.unreadCount = 0,
    this.searchQuery,
    this.isSearchActive = false,
  });

  FeedState copyWith({
    List<Article>? articles,
    List<Article>? savedArticles,
    List<Article>? displayedArticles,
    String? selectedCategory,
    ViewMode? viewMode,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    DateTime? lastRefreshTime,
    int? unreadCount,
    String? searchQuery,
    bool? isSearchActive,
    bool clearError = false,
  }) {
    return FeedState(
      articles: articles ?? this.articles,
      savedArticles: savedArticles ?? this.savedArticles,
      displayedArticles: displayedArticles ?? this.displayedArticles,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      viewMode: viewMode ?? this.viewMode,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
      unreadCount: unreadCount ?? this.unreadCount,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchActive: isSearchActive ?? this.isSearchActive,
    );
  }
}

/// Provider for managing feed screen state
/// Uses ChangeNotifier for reactive UI updates
class FeedProvider extends ChangeNotifier {
  final ArticleRepository _articleRepository;
  FeedState _state = const FeedState();

  FeedProvider({required ArticleRepository articleRepository})
      : _articleRepository = articleRepository;

  /// Current feed state
  FeedState get state => _state;

  /// Get articles list
  List<Article> get articles => _state.articles;

  /// Get saved articles list
  List<Article> get savedArticles => _state.savedArticles;

  /// Get displayed/filtered articles
  List<Article> get displayedArticles => _state.displayedArticles;

  /// Get selected category filter
  String get selectedCategory => _state.selectedCategory;

  /// Get current view mode
  ViewMode get viewMode => _state.viewMode;

  /// Check if loading
  bool get isLoading => _state.isLoading;

  /// Check if refreshing
  bool get isRefreshing => _state.isRefreshing;

  /// Get current error message
  String? get errorMessage => _state.errorMessage;

  /// Get last refresh time
  DateTime? get lastRefreshTime => _state.lastRefreshTime;

  /// Get unread count
  int get unreadCount => _state.unreadCount;

  /// Get search query
  String? get searchQuery => _state.searchQuery;

  /// Check if search is active
  bool get isSearchActive => _state.isSearchActive;

  /// Initialize the provider - load saved articles and existing data
  Future<void> init({bool showSavedOnly = false}) async {
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    try {
      // Load saved articles and all articles in parallel
      final results = await Future.wait([
        _articleRepository.fetchSavedArticles(),
        _articleRepository.fetchAllArticles(),
      ]);

      final savedResult = results[0] as Result<List<Article>>;
      final allResult = results[1] as Result<List<Article>>;

      if (savedResult.isSuccess) {
        _state = _state.copyWith(
          savedArticles: savedResult.data ?? [],
        );
      }

      if (allResult.isSuccess) {
        _state = _state.copyWith(
          articles: allResult.data ?? [],
          displayedArticles: showSavedOnly
              ? (savedResult.data ?? [])
              : (allResult.data ?? []),
          isLoading: false,
        );
      } else {
        _state = _state.copyWith(
          errorMessage: allResult.error ?? 'Failed to load articles',
          isLoading: false,
        );
      }

      // Get unread count independently
      await _updateUnreadCount();
    } catch (e) {
      _state = _state.copyWith(
        errorMessage: ErrorHandler.getUserMessage(e),
        isLoading: false,
      );
    }

    notifyListeners();
  }

  /// Refresh articles from Worker API
  Future<void> refreshArticles() async {
    _state = _state.copyWith(isRefreshing: true, clearError: true);
    notifyListeners();

    try {
      final result = await _articleRepository.fetchNewArticles();
      if (result.isSuccess) {
        _state = _state.copyWith(
          articles: result.data ?? _state.articles,
          displayedArticles: _filterArticles(result.data ?? _state.articles),
          lastRefreshTime: DateTime.now(),
          isRefreshing: false,
        );
        await _updateUnreadCount();
      } else {
        _state = _state.copyWith(
          errorMessage: result.error ?? 'Failed to refresh articles',
          isRefreshing: false,
        );
      }
    } catch (e) {
      _state = _state.copyWith(
        errorMessage: ErrorHandler.getUserMessage(e),
        isRefreshing: false,
      );
    }

    notifyListeners();
  }

  /// Filter by category
  void filterByCategory(String category) {
    _state = _state.copyWith(
      selectedCategory: category,
      displayedArticles: _filterArticlesByCategory(_state.articles, category),
      clearError: true,
    );
    notifyListeners();
  }

  /// Search articles
  void search(String query) {
    if (query.isEmpty) {
      _state = _state.copyWith(
        searchQuery: null,
        isSearchActive: false,
        displayedArticles: _filterArticlesByCategory(
          _state.articles,
          _state.selectedCategory,
        ),
        clearError: true,
      );
    } else {
      _filterBySearch(query);
    }
    notifyListeners();
  }

  /// Toggle search mode
  void setSearchActive(bool active) {
    _state = _state.copyWith(
      isSearchActive: active,
      searchQuery: active ? '' : null,
      displayedArticles: active
          ? _state.displayedArticles
          : _filterArticlesByCategory(_state.articles, _state.selectedCategory),
      clearError: true,
    );
    notifyListeners();
  }

  /// Toggle view mode (cards/list)
  void setViewMode(ViewMode mode) {
    _state = _state.copyWith(viewMode: mode);
    notifyListeners();
  }

  /// Toggle save/unsave article
  Future<void> toggleSaveArticle(Article article) async {
    try {
      final newSavedState = !article.isSaved;
      final result = await _articleRepository.toggleSave(
        article,
        isSaved: newSavedState,
      );

      if (result.isSuccess) {
        // Update local articles list
        final updatedArticles = _state.articles.map((a) {
          if (a.id == article.id) {
            return a.copyWith(isSaved: newSavedState);
          }
          return a;
        }).toList();

        // Update saved articles list
        List<Article> updatedSavedArticles;
        if (newSavedState) {
          updatedSavedArticles = [
            article.copyWith(isSaved: true),
            ..._state.savedArticles.where((a) => a.id != article.id),
          ];
        } else {
          updatedSavedArticles = _state.savedArticles
              .where((a) => a.id != article.id)
              .toList();
        }

        _state = _state.copyWith(
          articles: updatedArticles,
          savedArticles: updatedSavedArticles,
          displayedArticles: _state.selectedCategory == 'All' || _state.isSearchActive
              ? _filterArticles(updatedArticles)
              : _state.displayedArticles,
        );
        notifyListeners();
      } else {
        _state = _state.copyWith(errorMessage: result.error ?? 'Failed to save article');
        notifyListeners();
      }
    } catch (e) {
      _state = _state.copyWith(errorMessage: ErrorHandler.getUserMessage(e));
      notifyListeners();
    }
  }

  /// Mark article as read
  Future<void> markAsRead(Article article) async {
    try {
      if (article.isRead) return; // Already read

      final result = await _articleRepository.markAsRead(article);
      if (result.isSuccess) {
        // Update local state
        final updatedArticles = _state.articles.map((a) {
          if (a.id == article.id) {
            return a.copyWith(isRead: true);
          }
          return a;
        }).toList();

        _state = _state.copyWith(
          articles: updatedArticles,
          displayedArticles: _filterArticles(updatedArticles),
          unreadCount: (_state.unreadCount - 1).clamp(0, _state.unreadCount),
        );
        notifyListeners();
      }
    } catch (e) {
      ErrorHandler.logError(
        'Failed to mark article as read',
        error: e,
        severity: ErrorSeverity.low,
      );
    }
  }

  /// Refresh unread count
  Future<void> refreshUnreadCount() async {
    await _updateUnreadCount();
  }

  /// Clear error message
  void clearError() {
    _state = _state.copyWith(errorMessage: null);
    notifyListeners();
  }

  /// Filter articles based on current category/search state
  List<Article> _filterArticles(List<Article> articles) {
    if (_state.isSearchActive && _state.searchQuery != null && _state.searchQuery!.isNotEmpty) {
      return _filterBySearchQuery(articles, _state.searchQuery!);
    }
    return _filterArticlesByCategory(articles, _state.selectedCategory);
  }

/// Filter articles by category
  List<Article> _filterArticlesByCategory(List<Article> articles, String category) {
    return Helpers.filterArticlesByCategory(articles, category);
  }

  /// Filter by search query
  void _filterBySearch(String query) {
    _state = _state.copyWith(
      searchQuery: query,
      isSearchActive: true,
      displayedArticles: _filterBySearchQuery(_state.articles, query),
    );
  }

/// Search articles by query
  List<Article> _filterBySearchQuery(List<Article> articles, String query) {
    return Helpers.filterArticlesByQuery(articles, query);
  }

  /// Update unread count from repository
  Future<void> _updateUnreadCount() async {
    try {
      final result = await _articleRepository.getUnreadCount();
      if (result.isSuccess) {
        _state = _state.copyWith(unreadCount: result.data ?? 0);
      }
    } catch (e) {
      ErrorHandler.logError(
        'Failed to get unread count',
        error: e,
        severity: ErrorSeverity.low,
      );
    }
  }
}
