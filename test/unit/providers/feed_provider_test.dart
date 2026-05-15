import 'package:flutter_test/flutter_test.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/models/filter_params.dart';
import 'package:curatedfeeds/providers/feed_provider.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/utils/error_handler.dart';

/// Mock ArticleRepository for testing FeedProvider
class MockArticleRepository implements ArticleRepository {
  List<Article> savedArticlesToReturn = [];
  List<Article> allArticlesToReturn = [];
  int unreadCountToReturn = 0;
  bool fetchSavedArticlesSuccess = true;
  bool fetchAllArticlesSuccess = true;
  String? savedArticlesError;
  String? allArticlesError;
  bool markAsReadSuccess = true;

  @override
  List<Article>? _cachedSavedArticles;

  @override
  List<Article>? _cachedArticles;

  @override
  void clearCache() {
    _cachedSavedArticles = null;
    _cachedArticles = null;
  }

  @override
  Future<Result<List<Article>>> fetchSavedArticles() async {
    if (!fetchSavedArticlesSuccess) {
      return Result.failure(savedArticlesError ?? 'Failed to fetch saved');
    }
    return Result.success(savedArticlesToReturn);
  }

  @override
  Future<Result<List<Article>>> fetchAllArticles({bool forceRefresh = false}) async {
    if (!fetchAllArticlesSuccess) {
      return Result.failure(allArticlesError ?? 'Failed to fetch all');
    }
    return Result.success(allArticlesToReturn);
  }

  @override
  Future<Result<List<Article>>> fetchNewArticles() async {
    return Result.success(allArticlesToReturn);
  }

  @override
  Future<Result<List<Article>>> fetchArticlesFromSource(String sourceId) async {
    return Result.success([]);
  }

  @override
  Future<Result<List<Article>>> searchArticles(String query) async {
    return Result.success([]);
  }

  @override
  Future<Result<List<Article>>> filterByCategory(String category) async {
    return Result.success([]);
  }

  @override
  Future<Result<List<Article>>> filterUnread() async {
    return Result.success([]);
  }

  @override
  Future<Result<void>> markAsRead(Article article) async {
    if (!markAsReadSuccess) {
      return Result.failure('Failed to mark as read');
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> toggleSave(Article article, {bool isSaved = false}) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> removeArticle(String articleId) async {
    return Result.success(null);
  }

  @override
  Future<Result<int>> getUnreadCount() async {
    return Result.success(unreadCountToReturn);
  }

  @override
  Future<Result<List<Article>>> fetchArticlesWithFilters(FilterParams params) async {
    return Result.success([]);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> fetchAvailableSources() async {
    return Result.success([]);
  }

  @override
  Future<Result<Map<String, dynamic>?>> fetchArticleFullContent(String articleUrl) async {
    return Result.success(null);
  }

  @override
  Future<void> replayOutbox() async {}
}

Article makeArticle({
  String id = 'test-1',
  String sourceId = 'test-source',
  String title = 'Test Article',
  bool isRead = false,
  bool isSaved = false,
}) {
  return Article(
    id: id,
    title: title,
    description: 'Test description',
    fullContent: 'Test content',
    link: 'https://example.com/$id',
    sourceId: sourceId,
    sourceName: 'Test Source',
    pubDate: DateTime.now(),
    isRead: isRead,
    isSaved: isSaved,
  );
}

void main() {
  group('FeedProvider', () {
    late FeedProvider feedProvider;
    late MockArticleRepository mockRepository;

    setUp(() {
      mockRepository = MockArticleRepository();
      feedProvider = FeedProvider(articleRepository: mockRepository);
    });

    group('init', () {
      test('init with showSavedOnly=true loads saved articles as displayed', () async {
        // Setup: saved articles and all articles are different
        final savedArticles = [
          makeArticle(id: 'saved-1', isSaved: true),
          makeArticle(id: 'saved-2', isSaved: true),
        ];
        final allArticles = [
          makeArticle(id: 'saved-1', isSaved: true),
          makeArticle(id: 'saved-2', isSaved: true),
          makeArticle(id: 'unsaved-1', isSaved: false),
        ];

        mockRepository.savedArticlesToReturn = savedArticles;
        mockRepository.allArticlesToReturn = allArticles;

        // Act
        await feedProvider.init(showSavedOnly: true);

        // Assert: displayedArticles should be the saved articles, not all articles
        expect(feedProvider.displayedArticles.length, 2);
        expect(feedProvider.displayedArticles.every((a) => a.isSaved), true);
        expect(feedProvider.state.isLoading, false);
      });

      test('init with showSavedOnly=false loads all articles as displayed', () async {
        // Setup
        mockRepository.savedArticlesToReturn = [
          makeArticle(id: 'saved-1', isSaved: true),
        ];
        mockRepository.allArticlesToReturn = [
          makeArticle(id: 'saved-1', isSaved: true),
          makeArticle(id: 'unsaved-1', isSaved: false),
          makeArticle(id: 'unsaved-2', isSaved: false),
        ];

        // Act
        await feedProvider.init(showSavedOnly: false);

        // Assert
        expect(feedProvider.displayedArticles.length, 3);
      });

      test('init with allResult.isSuccess=false sets error message', () async {
        // Setup: saved succeeds but all fails
        mockRepository.fetchSavedArticlesSuccess = true;
        mockRepository.fetchAllArticlesSuccess = false;
        mockRepository.allArticlesError = 'Network error';
        mockRepository.savedArticlesToReturn = [makeArticle(id: 'saved-1')];
        mockRepository.allArticlesToReturn = [];

        // Act
        await feedProvider.init();

        // Assert: error is set
        expect(feedProvider.errorMessage, isNotNull);
        expect(feedProvider.errorMessage, contains('Network error'));
        expect(feedProvider.state.isLoading, false);
      });

      test('init with fetchSavedArticles failure still loads all articles', () async {
        // Setup: saved fails but all succeeds
        mockRepository.fetchSavedArticlesSuccess = false;
        mockRepository.savedArticlesError = 'Storage error';
        mockRepository.fetchAllArticlesSuccess = true;
        mockRepository.allArticlesToReturn = [makeArticle(id: 'article-1')];

        // Act
        await feedProvider.init();

        // Assert: articles are still loaded, error is set from allResult
        // Actually looking at the code, if savedResult fails it doesn't set error,
        // only if allResult fails sets error. Let's verify this behavior.
        expect(feedProvider.articles.length, 1);
      });

      test('init clears previous error on success', () async {
        // Setup: first init fails
        mockRepository.fetchAllArticlesSuccess = false;
        await feedProvider.init();
        expect(feedProvider.errorMessage, isNotNull);

        // Reset: second init succeeds
        mockRepository.fetchAllArticlesSuccess = true;
        mockRepository.allArticlesToReturn = [makeArticle(id: 'article-1')];

        // Act
        await feedProvider.init();

        // Assert: previous error is cleared
        expect(feedProvider.errorMessage, isNull);
      });

      test('init sets isLoading true at start and false at end', () async {
        mockRepository.allArticlesToReturn = [makeArticle()];

        // Track loading state - add listener BEFORE calling init
        final loadingStates = <bool>[];
        feedProvider.addListener(() {
          loadingStates.add(feedProvider.isLoading);
        });

        // Kick off init but don't await yet - isLoading should already be true
        final initFuture = feedProvider.init();

        // Wait a tick for the async init to set isLoading = true
        await Future.delayed(Duration.zero);

        // At this point init() should have set isLoading to true
        expect(loadingStates.first, true);

        await initFuture;

        // Should have: true (start), false (end)
        expect(loadingStates.first, true);
        expect(loadingStates.last, false);
      });

      test('init updates unread count', () async {
        mockRepository.unreadCountToReturn = 5;
        mockRepository.allArticlesToReturn = [makeArticle(id: 'a1')];
        mockRepository.savedArticlesToReturn = [];

        await feedProvider.init();

        expect(feedProvider.unreadCount, 5);
      });
    });

    group('state management', () {
      test('initial state has correct defaults', () {
        expect(feedProvider.articles, isEmpty);
        expect(feedProvider.savedArticles, isEmpty);
        expect(feedProvider.displayedArticles, isEmpty);
        expect(feedProvider.isLoading, false);
        expect(feedProvider.errorMessage, isNull);
        expect(feedProvider.selectedCategory, 'All');
      });

      test('clearError removes error message', () async {
        // Set an error first
        mockRepository.fetchAllArticlesSuccess = false;
        await feedProvider.init();
        expect(feedProvider.errorMessage, isNotNull);

        // Act
        feedProvider.clearError();

        // Assert
        expect(feedProvider.errorMessage, isNull);
      });
    });

    group('filterByCategory', () {
      test('updates selected category', () async {
        await feedProvider.init();

        feedProvider.filterByCategory('Tech');

        expect(feedProvider.selectedCategory, 'Tech');
      });
    });

    group('toggleSaveArticle', () {
      test('toggles article saved state', () async {
        mockRepository.allArticlesToReturn = [];
        await feedProvider.init();

        final article = makeArticle(id: 'toggle-test', isSaved: false);

        await feedProvider.toggleSaveArticle(article);

        // The method calls repository and updates state
        // We just verify it doesn't throw
      });
    });

    group('markAsRead', () {
      test('marks article as read', () async {
        mockRepository.allArticlesToReturn = [];
        await feedProvider.init();

        final article = makeArticle(id: 'read-test', isRead: false);

        await feedProvider.markAsRead(article);

        // The method calls repository and updates state
        // We just verify it doesn't throw
      });
    });
  });
}