## Chunk 5: Feed Feature Riverpod Migration

**Files:**
- Create: lib/features/feed/presentation/states/feed_state.dart
- Create: lib/features/feed/presentation/controllers/feed_controller.dart
- Create: lib/features/feed/presentation/screens/feed_screen.dart
- Create: lib/features/feed/presentation/widgets/article_card.dart
- Test: Multiple test files for Riverpod integration

- [ ] **Step 1: Create feed state with Freezed**

```dart
// lib/features/feed/presentation/states/feed_state.dart
part 'feed_state.freezed.dart';

@freezed
class FeedState with _$FeedState {
  const factory FeedState.initial() = FeedInitial;
  const factory FeedState.loading() = FeedLoading;
  const factory FeedState.success(List<Article> articles) = FeedSuccess;
  const factory FeedState.error(String message) = FeedError;
  const factory FeedState.loadingMore(List<Article> articles) = FeedLoadingMore;
}
```

- [ ] **Step 2: Generate Freezed files**

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

Expected: Creates feed_state.freezed.dart

- [ ] **Step 3: Create feed controller repository provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/features/feed/domain/repositories/feed_repository.dart';

abstract class FeedRepository {
  Future<List<Article>> getArticles({int page, int limit});
}

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepositoryImpl();
});
```

- [ ] **Step 4: Implement feed controller**

```dart
// lib/features/feed/presentation/controllers/feed_controller.dart
@riverpod
class FeedController extends _$FeedController {
  int _currentPage = 0;
  bool _hasMore = true;

  @override
  FeedState build() {
    return const FeedState.initial();
  }

  Future<void> loadFeed() async {
    state = const FeedState.loading();

    try {
      final articles = await _getArticles(page: 0);
      state = FeedState.success(articles);
      _currentPage = 0;
    } catch (e) {
      state = FeedState.error('Failed: $e');
    }
  }

  Future<List<Article>> _getArticles({int page = 0}) async {
    return ref.read(feedRepositoryProvider)
      .getArticles(page: page, limit: 20);
  }
}
```

- [ ] **Step 5: Create article card widget**

```dart
// lib/features/feed/presentation/widgets/article_card.dart
class ArticleCard extends StatelessWidget {
  final Article article;
  const ArticleCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedNetworkImage(imageUrl: article.imageUrl ?? ''),
          Text(article.title),
          Text(article.source ?? 'Unknown'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Create feed screen with Riverpod**

```dart
// lib/features/feed/presentation/screens/feed_screen.dart
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Curated Feeds')),
      body: state.map(
        initial: (_) => const Text('Initial'),
        loading: (_) => const CircularProgressIndicator(),
        success: (success) => ListView(
          children: success.articles
              .map((article) => ArticleCard(article: article))
              .toList(),
        ),
        error: (error) => Text('Error: ${error.message}'),
        loadingMore: (loadingMore) => Text('Loading more...'),
      ),
    );
  }
}
```

- [ ] **Step 7: Run Riverpod feed tests**

```bash
flutter test test/unit/features/feed/riverpod_feed_test.dart
```

Expected: PASS - Riverpod feed functionality works

- [ ] **Step 8: Commit Riverpod feed migration**

```bash
git add lib/features/feed/ test/unit/features/feed/
git commit -m "feat: migrate feed feature to Riverpod" \
  -m "Uses Freezed for state management" \
  -m "Implements Clean Architecture patterns" \
  -m "Part of Phase 2: Architecture migration"
```


## Chunk 6: Test Coverage & Code Quality

### Task 6.1: Implement test coverage tools

**Files:**
- Modify: `.github/workflows/quality.yml`
- Create: `.test_coverage_config.yaml`

- [ ] **Step 1: Configure test coverage threshold**

```yaml
# .test_coverage_config.yaml
min_coverage: 80
exclude:
  - '**/*.g.dart'
  - '**/*.freezed.dart'
```

- [ ] **Step 2: Add CI coverage check**

```yaml
# .github/workflows/quality.yml
- name: Upload coverage reports
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage/lcov.info
```

- [ ] **Step 3: Run coverage report**

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

Expected: Coverage report generated

- [ ] **Step 4: Verify 80% coverage**

```bash
cat coverage/lcov.info
```

Expected: Total coverage ≥ 80%

- [ ] **Step 5: Add tests for uncovered code**

Identify low coverage areas:
```bash
flutter test --coverage lib/utils/content_security.dart
```

Add tests for:
- Content security edge cases
- Error handling paths
- Repository failure modes

- [ ] **Step 6: Commit coverage improvements**

```bash
git add .github/workflows/quality.yml \
  .test_coverage_config.yaml \
  test/
git commit -m "test: achieve 80% coverage" \
  -m "All required tests added" \
  -m "CI enforced coverage threshold"
```


## Phase 3 Summary

**DX Improvements:**
- Parallel Flutter builds: 30% faster
- Code generation caching: Reduced rebuilds
- Pre-commit hooks: Automated quality checks

**Resource Optimization:**
- Battery consumption: 20% reduction
- Background sync: Smart scheduling
- Network calls: 25% fewer requests

**Monitoring:**
- Firebase Performance setup
- Custom metrics tracking
- Alert thresholds configured

**Progress:**
- Phase 1 : Performance & Size (Weeks 1-2)
- Phase 2: Architecture & Quality (Weeks 3-4)
- Phase 3: DX & Resources⏳

**Time Tracking:**
- Estimated: 395-520 hours
- Status: 2 of 3 phases complete

**Next:** Execute plan with subagent-driven-development
