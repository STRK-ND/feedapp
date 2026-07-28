import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/repositories/article_repository.dart';
import 'package:curatedfeeds/utils/error_handler.dart';

void main() {
  group('ArticleRepository', () {
    late ArticleRepository repository;

    setUpAll(() {
      GetIt.instance.reset();
    });

    setUp(() async {
      await setupServiceLocator();
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
  });
}
