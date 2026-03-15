# Curated Feeds - Flutter Codebase Optimization Design

**Author:** Claude (via brainstorming skill)
**Date:** 2026-03-15
**Version:** 1.0
**Status:** Approved for Implementation

## Executive Summary

Comprehensive optimization of the Curated Feeds Flutter RSS reader application targeting five critical dimensions: **Performance**, **Code Quality**, **Developer Experience**, **App Size**, and **Battery/Resource Usage**. The optimization will be executed in three phases over a 5-week timeline with measurable targets for each phase.

## Project Overview

**Application Name:** Curated Feeds
**Platform:** Flutter (iOS, Android)
**Current State:** Active development with recent architecture improvements
**Flutter SDK:** ^3.10.8

### Current Tech Stack
- **Core:** Flutter + Dart
- **State Management:** Provider + GetIt
- **Networking:** http, xml, html
- **Storage:** SharedPreferences, Flutter Secure Storage, Flutter Cache Manager
- **Firebase:** Core, Analytics, Messaging
- **UI:** Material/Cupertino with custom widgets

## Optimization Goals

### Performance Targets
- **App startup time:** Reduce by 40%
- **UI smoothness:** Consistent 60fps scrolling
- **Memory footprint:** Reduce by 30%
- **Tab switching:** <100ms response time

### Code Quality Targets
- **Test coverage:** Increase to 80%
- **Code duplication:** <5%
- **Architecture violations:** 0
- **Technical debt:** Reduce by 50%

### Developer Experience Targets
- **Build time:** Reduce by 30%
- **Test execution:** Reduce by 40%
- **Developer satisfaction:** >80% positive feedback

### App Size Targets
- **APK size:** Reduce by 25%

### Resource Efficiency Targets
- **Battery consumption:** Reduce by 20%
- **Background task efficiency:** Improve by 25%
- **Network optimization:** Implement intelligent caching

## Phased Approach

The optimization follows a three-phase approach recommended by Claude:

```
┌─────────────────────────────────────────────────────────────┐
│                    PHASE 1: Performance & Size               │
│                     Weeks 1-2: Critical Metrics              │
├─────────────────────────────────────────────────────────────┤
│  • App startup optimization                                 │
│  • Scroll performance improvements                           │
│  • Memory footprint reduction                                │
│  • APK size reduction                                        │
│  • Build optimizations                                       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     PHASE 2: Code Quality                    │
│              Weeks 3-5: Architecture & Testing               │
├─────────────────────────────────────────────────────────────┤
│  • Architecture improvements (Riverpod migration - 2 weeks) │
│  • Comprehensive testing (80% coverage - 1 week)             │
│  • Code duplication elimination                              │
│  • Technical debt reduction                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                 PHASE 3: DX & Resource Usage                 │
│                          Week 5: Polish                    │
├─────────────────────────────────────────────────────────────┤
│  • CI/CD optimizations                                       │
│  • Developer tooling improvements                            │
│  • Battery usage optimization                              │
│  • Resource monitoring implementation                        │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

### Critical: Flutter SDK Version Resolution

**BLOCKING ISSUE:** Flutter Secure Storage 10.x requires Flutter SDK ^3.19.0, but the project currently specifies Flutter ^3.10.8.

**Decision Required Before Starting:**

**Option A: Upgrade Flutter SDK (RECOMMENDED)**
- Upgrade Flutter SDK to ^3.19.0
- Audit all dependencies for breaking changes
- Update CI/CD pipeline Flutter version
- Update build documentation

```yaml
# In pubspec.yaml
environment:
  sdk: ^3.19.0  # Dart 3.0.x
  flutter: ^3.19.0

# Also update .github/workflows/flutter.yml
deploy:
  runs-on: ubuntu-latest
  steps:
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.19.x'
```

**Option B: Downgrade Flutter Secure Storage**
- Downgrade to flutter_secure_storage ^8.0.0 (last version compatible with Flutter 3.10)
- Accept reduced security features
- Use as temporary bridge (upgrade in Phase 2)

```yaml
# This works with Flutter 3.10
flutter_secure_storage: ^8.0.0
```

**Decision Impact:** This must be resolved before Week 1, Day 1. We'll use Option A and upgrade Flutter SDK.

### Flutter Secure Storage Verification

After upgrading Flutter SDK, verify Flutter Secure Storage usage:

```bash
# Check current usage patterns
grep -r "FlutterSecureStorage" lib/

# Verify migration compatibility
flutter pub deps | grep flutter_secure_storage
```

**Breaking Changes in Flutter Secure Storage 10.x:**
- iOS: Requires Keychain entitlements
- Android: No breaking changes
- Desktop: Breaking changes (not used in this project)

### Firebase SDK Version Compatibility

**Current Constraints:**
```yaml
firebase_core: ^3.8.0
firebase_analytics: ^11.6.0
firebase_messaging: ^15.1.6
```

With Flutter 3.19, use latest Firebase packages:
```yaml
firebase_core: ^3.11.0
firebase_analytics: ^11.6.0  # Compatible with 3.19
firebase_messaging: ^15.1.6   # Compatible with 3.19
```

**Verification Command:**
```bash
flutter pub outdated
```

### Riverpod Migration Prerequisites

**Target Riverpod Version:** riverpod ^2.5.1 with Flutter 3.19

**Compatibility Matrix:**
| Flutter Version | Riverpod Version | State Management | Status |
|-----------------|------------------|------------------|--------|
| 3.10.8 | 2.4.x | Provider | Broken |
| 3.19.0 | 2.5.1 | Riverpod | Target |

**Bridge Pattern Implementation:**
Create compatibility bridge for gradual migration:

```dart
// lib/core/bridge/provider_bridge.dart
class ProviderBridge {
  static T watch<T>(BuildContext context, dynamic provider) {
    if (provider is InheritedWidget) {
      // Provider pattern
      return Provider.of<T>(context, listen: true);
    } else if (provider is ProviderListenable) {
      // Riverpod pattern
      return ProviderScope.containerOf(context).read(provider);
    }
    throw UnsupportedError('Unknown provider type: $provider');
  }
}

// Usage during migration
class FeedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final feed = ProviderBridge.watch<List<Article>>(
      context,
      // Can be either Provider or Riverpod during migration
      feedControllerProvider,
    );
    return FeedList(feed: feed);
  }
}
```

### Development Environment Setup

**Required for All Team Members:**
- Flutter SDK ^3.19.0 installed with `flutter --version` verification
- Dart SDK ^3.3.0 (comes with Flutter)
- Android Studio or VS Code with Flutter extensions
- Xcode 15.2+ (for iOS testing)
- Git with proper SSH key setup

**Verification Script:**
```bash
#!/bin/bash
echo "Checking prerequisites..."
flutter --version | grep "Flutter 3.19"
flutter pub get
dart analyze --fatal-warnings lib/
flutter test --shard-index=0 --total-shards=1 --track-widget-creation
```

### Dependency Version Verification

Before starting, create pinned versions file:

```yaml
# .versions.lock
flutter: "3.19.6"
dart: "3.3.4"
firebase_core: "3.11.0"
riverpod: "2.5.1"
flutter_secure_storage: "10.0.0"
```

**Lock Dependencies:**
```bash
flutter pub get --enforce-lockfile
```

### Security Configuration

**HTTPS Mixed Content Risk Mitigation:**

Feeds may load HTTP images in HTTPS contexts. Implement content security proxy:

```dart
// In FeedContentService
class FeedContentService {
  String sanitizeImageUrl(String url) {
    if (url.startsWith('http://')) {
      // Option 1: Proxy through HTTPS service
      return 'https://imageproxy.example.com?url=${Uri.encodeComponent(url)}';
      // Option 2: Block HTTP content
      // throw InsecureContentException('HTTP images not allowed: $url');
    }
    return url;
  }
}
```

**Content Security Policy:**
- Block mixed content by default on iOS
- Provide proxy service for HTTP assets
- Document in privacy policy

**Verification:**
```bash
# Check for HTTP URLs in code
grep -r "http://" lib/ --include="*.dart"

# Check network_security_config.xml
cat android/app/src/main/res/xml/network_security_config.xml
```

### iOS Provisioning & Entitlements

**Keychain Access:**
Flutter Secure Storage 10.x requires keychain entitlements for iOS:

```xml
<!-- ios/Runner/Runner.entitlements -->
<key>keychain-access-groups</key>
<array>
  <string>$(AppIdentifierPrefix)com.example.app</string>
</array>
```

**Testing Requirement:**
- Physical iOS device required (security features won't work in simulator)
- iOS 11.0+ deployment target

---

**Prerequisites Checklist:**

*These items must be completed before Week 1, Day 1.*

- [ ] **Flutter SDK upgraded to ^3.19.0**
- [ ] **All dependencies verified compatible with Flutter 3.19**
- [ ] **Flutter Secure Storage 10.x configuration verified**
- [ ] **Firebase SDK versions pinned and tested**
- [ ] **Bridge pattern implemented (or design finalized)**
- [ ] **Development environment configured on all team machines**
- [ ] **HTTPS content proxy service configured (or decision made to block HTTP)**
- [ ] **iOS entitlements added and code signing configured**
- [ ] **Prerequisites verification script passes**
- [ ] **Git branching strategy approved and documented**
- [ ] **Feature flags infrastructure implemented**

**⚠️ CRITICAL**: Projects cannot proceed without satisfying Flutter SDK and dependency requirements.

**Day 3-5: Quick Win Optimizations**

**App Size Reduction:**
1. **Dependency Audit**
   - Remove unused packages from pubspec.yaml
   - Check for duplicate functionality (e.g., http vs dio)
   - Verify Firebase dependencies (remove unused Firebase services)

2. **Asset Optimization**
   - Analyze asset bundle size
   - Convert PNGs to WebP where applicable (especially feed thumbnails)
   - Compress fonts if custom fonts are used

3. **Build Configuration**
   - Enable R8/ProGuard for release builds
   - Verify tree shaking is working correctly
   - Remove debug code from release builds

4. **Cache Optimization**
   - Configure pub_cache for faster dependency resolution
   - Implement aggressive caching strategy for dependencies

**Code Changes:**
```yaml
# android/app/build.gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

#### Week 2: Deep Performance Optimization

**Day 1: Startup Profiling**
- [ ] Use DevTools CPU profiler to identify bottlenecks in main()
- [ ] Trace initialization sequence: main() → runApp() → first frame
- [ ] Identify heavy synchronous operations during startup
- [ ] Profile feed loading sequence

**Expected Findings:**
- FeedService initialization blocking startup
- Widget tree building inefficiencies
- Unnecessary rebuilds during launch

**Day 2-4: Implementation**

**Startup Optimization:**
1. **Lazy Initialization**
   ```dart
   // Before
   void main() {
     setupServices();
     runApp(MyApp());
   }

   // After
   void main() {
     runApp(MyApp());
     // Initialize services asynchronously after first frame
     SchedulerBinding.instance.addPostFrameCallback((_) {
       setupServices();
     });
   }
   ```

2. **Widget Rebuild Optimization**
   - Use Consumer widgets from Riverpod instead of Provider pattern
   - Implement proper keys for list items
   - Use `const` constructors where possible
   - Use `select` for granular rebuilds (targeted rebuilds vs subset selection)

3. **Image Loading Optimization**
   - Enable WebP format in cached_network_image
   - Implement progressive image loading (thumbnail → full)
   - Add proper image sizing to prevent layout thrashing

4. **Feed List Optimization**
   - Implement pagination with appropriate page size (20-30 items)
   - Use `SliverLists` for custom scroll effects
   - Optimize card widgets in FeedScreen

**Day 5: Verification**
1. Re-run baseline benchmarks
2. Performance regression test suite creation
3. Cross-platform testing (iOS and Android)

**Phase 1 Deliverables:**
- [ ] Complete benchmark report
- [ ] Performance regression test suite
- [ ] 30-40% performance improvement measured
- [ ] APK size reduced by 25%

### Phase 2: Code Quality (Weeks 3-4)

#### Week 3: Architecture & Patterns

**Day 1-2: Code Quality Assessment**
1. Run comprehensive code analysis:
   ```bash
   flutter pub run dart_code_metrics:metrics lib --report-on='lib'
   ```

2. **Identify Key Issues:**
   - Code duplication hotspots
   - High cyclomatic complexity functions
   - Architecture violations
   - Test coverage gaps
   - Technical debt areas

3. **Architecture Review**
   - Current: Provider + GetIt pattern
   - Current packages: repositories, services, providers, models, widgets
   - Migration target: Clean Architecture + Riverpod

**Day 3-5: Architecture Migration**

**Riverpod Migration Strategy:**
1. **Incrementally migrate by feature:**
   - Start with FeedScreen
   - Then ArticleDetailScreen
   - Move to services and repositories
   - Finally migrate widgets

2. **New Architecture Pattern:**
```
lib/
├── core/
│   ├── error/
│   ├── network/
│   └── utils/
├── features/
│   ├── feed/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── article/
│       ├── data/
│       ├── domain/
│       └── presentation/
└── main.dart
```

3. **Riverpod Implementation:**
```dart
// Replace Provider with Riverpod providers
// lib/providers/feed_provider.dart → lib/features/feed/presentation/feed_controller.dart

@riverpod
class FeedController extends _$FeedController {
  @override
  Future<List<Article>> build() async {
    return ref.watch(feedRepositoryProvider).getFeed();
  }
}
```

4. **Sealed Classes for Error Handling:**
```dart
@freezed
class FeedState with _$FeedState {
  const factory FeedState.initial() = _Initial;
  const factory FeedState.loading() = _Loading;
  const factory FeedState.success(List<Article> articles) = _Success;
  const factory FeedState.error(String message) = _Error;
}
```

5. **Dependency Injection Consolidation:**
- Consolidate GetIt and Provider into Riverpod providers
- Simplified service location: `ref.watch(serviceProvider)`

#### Week 4: Test Coverage & Refactoring

**Day 1-3: Comprehensive Testing**

**Test Coverage Goals:**
- Overall: 80% minimum
- Critical paths: 100%
- UI components: 70%
- Integration: Cover main user flows

**Testing Implementation:**

1. **Widget Tests:**
```dart
// Test feed screen loading states
testWidgets('FeedScreen shows loading state', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        feedControllerProvider.overrideWith(...)
      ],
      child: MaterialApp(home: FeedScreen()),
    ),
  );
  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

2. **Repository Tests:**
```dart
group('FeedRepository', () {
  late FeedRepository repository;
  late MockRssFeedService mockFeedService;

  setUp(() {
    mockFeedService = MockRssFeedService();
    repository = FeedRepositoryImpl(mockFeedService);
  });

  test('getFeed returns success', () async {
    // Arrange
    when(() => mockFeedService.fetchFeed())
        .thenAnswer((_) async => mockFeedData);

    // Act
    final result = await repository.getFeed();

    // Assert
    expect(result.isSuccess, true);
  });
});
```

3. **Golden Tests:**
```dart
testWidgets('FeedCard renders correctly', (tester) async {
  await tester.pumpWidgetBuilder(FeedCard(article: testArticle));
  await screenMatchesGolden(tester, 'feed_card');
});
```

**Day 4-5: Refactoring Sprint**

**Refinements:**
1. **Code Duplication Elimination:**
   - Extract common patterns in repository implementations
   - Create base classes for CRUD operations
   - Shared widget extraction

2. **Clean Architecture:**
   - Implement repository pattern consistently
   - Add use cases for business logic
   - Separate data and domain layers

3. **Code Generation:**
```yaml
# pubspec.yaml
dev_dependencies:
  freezed: ^2.4.0
  freezed_annotation: ^2.4.0
  json_serializable: ^6.7.0
  json_annotation: ^4.8.0
  build_runner: ^2.4.6
```

4. **Enhanced Linting:**
```yaml
# analysis_options.yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - always_declare_return_types
    - cancel_subscriptions
    - close_sinks
    - comment_references
    - one_member_abstracts
    - only_throw_errors
    - package_api_docs
    - prefer_expression_function_bodies
    - prefer_single_quotes
```

**Phase 2 Deliverables:**
- [ ] 80% test coverage
- [ ] Riverpod migration complete
- [ ] Code duplication <5%
- [ ] Architecture documentation
- [ ] CI/CD integration with quality gates

### Phase 3: DX & Resource Usage (Week 5)

#### Day 1-2: Developer Experience

**Build Optimization:**
1. **Parallel Flutter Builds:**
```bash
# Add to CI/CD
flutter test --concurrency=4
flutter build apk --split-debug-info=debug-info
```

2. **Code Generation Caching:**
```yaml
# .github/workflows/ci.yml
- name: Cache build runner
  uses: actions/cache@v3
  with:
    path: .dart_tool/build/
    key: ${{ runner.os }}-build_runner-${{ hashFiles('pubspec.lock') }}
```

3. **Test Optimization:**
```yaml
# Reduce test time with sharding
flutter test --coverage --test-randomize-ordering-seed=random --concurrency=4
```

**Tooling Enhancements:**
1. Pre-commit hooks for formatting, sort imports
2. Better logging: structured logger with levels
3. Debug visualizations for widget trees
4. Performance overlay in debug builds

#### Day 3-4: Resource Usage

**Battery Optimization:**
1. **Background Task Optimization:**
   - Review `WorkerFeedService` implementation
   - Implement exponential backoff for failed syncs
   - Add battery-aware scheduling

```dart
// Optimize background refresh
class WorkerFeedService {
  Future<void> refreshFeed() async {
    if (batteryLevel < 0.2 && !isCharging) {
      // Defer until charging or battery improves
      return;
    }

    if (DataConnectionChecker().hasConnection) {
      await _performSync();
    }
  }
}
```

2. **Intelligent Caching:**
- Extend cache TTL: 24h for metadata, 7d for images
- Implement LRU eviction for cache
- Add cache size limits

3. **Network Optimization:**
```dart
// Combine multiple API calls
Future<void> fetchFeedWithArticles() async {
  // Before: N separate calls
  // After: Single batched call
  final response = await _client.get('/feeds/batch');
  return response.data;
}
```

**Cache Implementation:**
```dart
// With Riverpod + Cache
@riverpod
Future<List<Article>> cachedArticles(CachedArticlesRef ref) async {
  // Cache for 1 hour
  ref.cacheFor(const Duration(hours: 1));
  return ref.watch(articleRepositoryProvider).getAll();
}
```

#### Day 5: Polish & Documentation

**CI/CD Pipeline:**
```yaml
# .github/workflows/quality.yml
name: Code Quality
on: [pull_request]
jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
      - name: Install dependencies
        run: flutter pub get
      - name: Run code metrics
        run: flutter pub run dart_code_metrics:metrics lib
      - name: Run tests
        run: flutter test --coverage
      - name: Check coverage
        uses: VeryGoodOpenSource/very_good_coverage@v1.2.0
        with:
          path: coverage/lcov.info
          min_coverage: 80
```

**Performance Dashboard:**
- Firebase Performance Monitoring setup
- Custom metrics tracking for critical flows
- Alert thresholds for performance regression
- Weekly performance reports

**Phase 3 Deliverables:**
- [ ] Build time reduced by 30%
- [ ] Battery consumption reduced by 20%
- [ ] Developer tooling improvements
- [ ] Performance monitoring dashboard
- [ ] Complete documentation

## Risk Management

### High-Risk Items & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Riverpod migration bugs | Medium | High | Feature flags, gradual rollout |
| Performance regression on older devices | Low | High | Performance testing on multiple devices |
| Build pipeline breakages | Low | Medium | CI testing, staged deployments |
| Developer learning curve | Medium | Low | Documentation, pair programming |
| Cache invalidation issues | Medium | High | LRU eviction, manual cache clear |

### Rollback Strategy

**Phase 1 Rollback:**
- Git tag: `baseline-phase1`
- Rollback command: `git revert -m 1 [merge-commit]`
- Time to rollback: < 30 minutes

**Phase 2 Rollback:**
- Use feature flags for Riverpod migration
- Gradual rollout: 10% → 50% → 100%
- Monitoring: Firebase Performance + Crashlytics

**Phase 3 Rollback:**
- Build configuration changes are easily reversible
- Developer tooling is additive (safe to rollback)

### Emergency Procedures

**Performance Emergency:**
1. Disable feed auto-refresh in app settings
2. Clear feeds cache
3. Revert network optimization changes
4. Hotfix release within 4 hours

**Architecture Emergency:**
1. Feature flag off for Riverpod changes
2. Monitor crash rate in Firebase
3. Revert migration changes
4. Restore Provider implementation

## Measurement & Tracking

### Phase 1 Metrics
- App startup time (DevTools trace)
- Scroll/framerate performance (DevTools FPS)
- APK size reduction (Build analyzer)
- Memory footprint (Dart DevTools)

**Targets:**
- Startup: -40%
- Memory: -30%
- APK: -25%
- Smooth scrolling: 60fps

### Phase 2 Metrics
- Test coverage: `flutter test --coverage`
- Code quality: `dart_code_metrics`
- Technical debt: Code Climate or SonarQube
- Architecture compliance: Custom lint rules

**Targets:**
- Coverage: 80%
- Duplication: <5%
- Complexity: <5 average
- Architecture violations: 0

### Phase 3 Metrics
- Build time: CI pipeline timing
- Battery: Android Battery Historian, iOS Instruments
- Network: Charles Proxy, Firebase Performance
- Developer satisfaction: Survey

**Targets:**
- Build time: -30%
- Battery: -20%
- Network calls: -25%
- Developer satisfaction: >80%

## Success Criteria

### Absolute Criteria (All Must Pass)
1. No regression in user-facing functionality
2. Crash rate < 1% (matches current baseline)
3. All critical user flows tested
4. Performance improvements verified on release builds

### Target Criteria (Strive to Achieve)
1. Phase 1 targets met within 10% margin
2. Phase 2 targets met with architectural improvements
3. Phase 3 targets met with measurable DX improvements
4. Developer feedback survey: >80% positive
5. Zero critical bugs reported in first week after launch

### Bonus Criteria (Nice to Have)
1. >10% better than target for any metric
2. Zero bugs reported in first month
3. Feature requests from optimization insights
4. Developer PR time reduced by >30%

## Timeline Summary

| Week | Phase | Focus | Key Activities | Deliverable |
|------|-------|-------|----------------|-------------|
| 1 | 1 | Baseline & Quick Wins | Measure, dependency audit, asset optimization | 10-15% improvement |
| 2 | 1 | Deep Performance | Startup optimization, list performance | 30-40% improvement |
| 3 | 2 | Architecture Pt 1 | Riverpod migration setup, bridge implementation | Migration infrastructure |
| 4 | 2 | Architecture Pt 2 | Complete Riverpod migration, Clean Architecture | Clean architecture |
| 5 | 2 | Code Quality | Tests (80% coverage), refactoring, linting | Quality improvements |
| 6 | 3 | DX & Resources | Build optimization, battery usage, documentation | -30% build time, -20% battery |

## Resources Required

### Personnel
- Flutter Developer: 100% (2-3 weeks)
- QA Engineer: 40% (testing phases)
- DevOps: 20% (CI/CD setup)

### Tools & Services
- Firebase Performance Monitoring ($0 - included in Spark plan)
- GitHub Actions (free for public repos)
- Code quality tools (free)
- Physical test devices (Android/iOS)

### Time Investment
- **Phase 1 Performance:** 80-100 hours (2 weeks)
- **Phase 2 Architecture:** 140-180 hours (3 weeks - includes learning curve)
- **Phase 3 DX & Resources:** 40-60 hours (1 week)
- **Testing & Validation:** 80-100 hours (ongoing)
- **Troubleshooting & Polish:** 40-60 hours
- **Documentation:** 15-20 hours
- **Total:** 395-520 hours (~6 weeks)

## Next Steps

1. **Week 1, Day 1:**
   - [ ] Create optimization branch: `git checkout -b optimization/phase-1`
   - [ ] Set up Firebase Performance Monitoring
   - [ ] Create benchmark script
   - [ ] Document current metrics

2. **Week 1, Day 2:**
   - [ ] Audit dependencies
   - [ ] Analyze APK size
   - [ ] Create measurement dashboard

3. **Week 1, Day 3:**
   - [ ] Implementation of quick wins
   - [ ] Begin setup for Riverpod (preparation)

4. **Continuous:**
   - [ ] Daily standup on progress
   - [ ] Weekly metric review
   - [ ] Bi-weekly stakeholder demo

## Appendix

### A. Measurement Setup
```bash
# Startup time measurement script
#!/bin/bash
echo "Measuring startup time..."
flutter run --release --trace-startup
# Parse timeline.json for first frame time
```

### B. Git Flow
```
main (stable)
├── optimization/phase-1 (feature flag enabled)
├── optimization/phase-2 (feature flag enabled)
└── optimization/phase-3 (feature flag enabled)
```

### C. Feature Flag Strategy
```dart
// Use this pattern for gated features
class FeatureFlags {
  static bool get useRiverpodMigration {
    return const bool.fromEnvironment('USE_RIVERPOD', defaultValue: false);
  }

  static bool get enableOptimizations {
    return const bool.fromEnvironment('ENABLE_OPTS', defaultValue: false);
  }
}
```

## References
- Flutter Performance Best Practices: https://flutter.dev/docs/perf
- Riverpod Migration Guide: https://riverpod.dev/docs/migration/
- Clean Architecture: https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html

---

**Document Status:** ✅ Approved for Implementation
**Next Step:** Create implementation plan using writing-plans skill
