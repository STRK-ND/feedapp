import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/models/filter_params.dart';
import 'package:curatedfeeds/models/paginated_response.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/services/feed_database.dart';
import 'package:curatedfeeds/services/storage_service.dart';
import 'package:curatedfeeds/services/worker_feed_service.dart';
import 'package:curatedfeeds/utils/error_handler.dart';

/// Worker stub that always returns the same fresh (unread, unsaved)
/// article. Simulates the live worker, which re-serves the whole feed
/// on every refresh regardless of client state.
class _ReplayedWorker extends WorkerFeedService {
  _ReplayedWorker(this.article);
  final Article article;

  @override
  Future<PaginatedResponse> fetchArticles({FilterParams? params}) async {
    return PaginatedResponse(
      items: [article],
      total: 1,
      page: 1,
      pageSize: 50,
      hasMore: false,
    );
  }
}

void main() {
  group('ArticleRepository', () {
    late ArticleRepository repository;

    setUpAll(() {
      GetIt.instance.reset();
    });

    setUp(() async {
      await setupServiceLocator();
      // Swap the default (file-based) storage for an isolated SQLite
      // database: no platform channel, per-test isolation via a unique
      // temp path (the ffi factory caches by path).
      sqfliteFfiInit();
      final dir = await Directory.systemTemp.createTemp('curatedfeeds_test');
      final db = await databaseFactoryFfi.openDatabase(
        '${dir.path}${Platform.pathSeparator}feed.db',
      );
      getIt.unregister<StorageService>();
      getIt.registerLazySingleton<StorageService>(
        () => StorageService(database: FeedDatabase(db: db)),
      );
      repository = ArticleRepository();
    });

    group('fetchAllArticles', () {
      test('Should return success Result from storage', () async {
        final result = await repository.fetchAllArticles();

        expect(result.isSuccess, true);
        expect(result.isFailure, false);
        expect(result.data, isNotNull);
        expect(result.error, isNull);
      });

      test('Should return Result type', () async {
        final result = await repository.fetchAllArticles();

        expect(result, isA<Result<List<Article>>>());
      });
    });

    group('fetchSavedArticles', () {
      test('Should return success Result', () async {
        final result = await repository.fetchSavedArticles();

        expect(result.isSuccess, true);
        expect(result.data, isNotNull);
      });
    });

    group('clearCache', () {
      test('Should clear internal cache', () async {
        await repository.fetchAllArticles();

        expect(() => repository.clearCache(), returnsNormally);
      });
    });

    // Regression: swiping an article read/saved marks it in place; the feed
    // screen keeps it in its list and pushes the flagged state into the repo
    // cache via syncFrom. The worker re-serves the full feed every refresh,
    // and the merge must preserve the existing flags — otherwise marked
    // articles reappear unread/unsaved after the next refresh.
    group('fetchNewArticles preserves flagged state across refresh', () {
      Article freshArticle() => Article(
        id: 'verge-abc',
        title: 'T',
        description: 'D',
        fullContent: '',
        link: 'https://e.com/a',
        sourceId: 'verge',
        sourceName: 'The Verge',
        pubDate: DateTime.utc(2026, 1, 1),
      );

      test(
        'marked-read survives a refresh that re-serves the article',
        () async {
          final worker = _ReplayedWorker(freshArticle());
          final repo = ArticleRepository(workerFeedService: worker);

          repo.syncFrom([freshArticle()..isRead = true], <Article>[]);

          final result = await repo.fetchNewArticles();
          expect(result.isSuccess, true);

          expect(result.data!.length, 1);
          expect(result.data!.first.id, 'verge-abc');
          expect(result.data!.first.isRead, true);
        },
      );

      test('saved article stays saved across a refresh', () async {
        final worker = _ReplayedWorker(freshArticle());
        final repo = ArticleRepository(workerFeedService: worker);

        repo.syncFrom([freshArticle()..isSaved = true], <Article>[]);

        final result = await repo.fetchNewArticles();
        expect(result.isSuccess, true);
        expect(result.data!.first.isSaved, true);
      });
    });
  });
}
