// Server-extracted full text (teaser feeds): the reader must prefer the
// worker-extracted `fullContent` without a client fetch, and surface it
// with a "Full text" badge so a power reader can trust the body.
import 'package:curatedfeeds/di/service_locator.dart';
import 'package:curatedfeeds/l10n/generated/app_localizations.dart';
import 'package:curatedfeeds/models/article.dart';
import 'package:curatedfeeds/providers/settings_notifier.dart';
import 'package:curatedfeeds/services/article_content_service.dart';
import 'package:curatedfeeds/services/settings_service.dart';
import 'package:curatedfeeds/services/storage_service.dart';
import 'package:curatedfeeds/widgets/expanded_article_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingContentService extends ArticleContentService {
  int calls = 0;

  @override
  Future<String> fetchArticleContent(String url) async {
    calls++;
    return 'Client-fetched body that must not be used.';
  }
}

/// StorageService double recording saved-row writes — the note dialog
/// persists through it.
class _RecordingStorageService extends StorageService {
  final List<Article> savedRows = [];

  @override
  Future<void> saveSavedArticle(Article article) async {
    savedRows.add(article);
  }
}

Article _article({required String fullContent, required String description}) {
  return Article(
    id: 'a1',
    title: 'Test Article Title',
    description: description,
    fullContent: fullContent,
    link: 'https://example.com/1',
    sourceId: 'verge',
    sourceName: 'The Verge',
    pubDate: DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );
}

Future<void> _pumpCard(WidgetTester tester, Article article) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SettingsNotifier>(
      create: (_) => SettingsNotifier(SettingsService()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExpandedArticleCard(
            article: article,
            onClose: () {},
            onToggleSave: () {},
          ),
        ),
      ),
    ),
  );
  // _initContent resolves asynchronously before the first frame paints.
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingContentService contentService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // reset() is async — awaiting it keeps the registration below from
    // being wiped when a pending disposal from the previous test lands.
    await getIt.reset();
    contentService = _RecordingContentService();
    getIt.registerSingleton<ArticleContentService>(contentService);
    getIt.registerSingleton<StorageService>(_RecordingStorageService());
  });

  testWidgets('server-extracted fullContent renders without a client fetch', (
    tester,
  ) async {
    final body = 'Server-extracted article body. ' * 20;
    final article = _article(fullContent: body, description: 'Teaser.');

    await _pumpCard(tester, article);

    // The reader shows the extracted body…
    expect(find.text(body), findsOneWidget);
    // …the teaser is not duplicated above it (identical-content guard is
    // irrelevant here: teaser != body, so the teaser WOULD render — see
    // the card's own rule; assert the extracted body is present and the
    // badge marks it).
    expect(find.text('Full text'), findsOneWidget);
    // No client-side fetch happened: the worker already did the work.
    expect(contentService.calls, 0);
  });

  testWidgets('teaser-only articles show no badge and fetch client-side', (
    tester,
  ) async {
    final article = _article(fullContent: '', description: 'Short teaser.');

    await _pumpCard(tester, article);

    expect(find.text('Full text'), findsNothing);
    // The pre-worker behaviour is preserved: the card fetches the body
    // itself and caches it on the article.
    expect(contentService.calls, 1);
    expect(article.fetchedFullContent, isNotNull);
  });

  testWidgets('note dialog: hidden for unsaved, saves for saved articles', (
    tester,
  ) async {
    final storage = getIt<StorageService>() as _RecordingStorageService;

    // Unsaved article: no Note button (icon-only header buttons carry
    // semantic labels, so find by icon).
    final unsaved = _article(fullContent: 'F' * 300, description: 'Teaser.');
    await _pumpCard(tester, unsaved);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsNothing);

    // Saved article: Note button opens the dialog; saving mutates the
    // shared article and persists the row.
    final saved = _article(fullContent: 'F' * 300, description: 'Teaser.')
      ..isSaved = true;
    await _pumpCard(tester, saved);
    await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Key takeaway: cache it');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved.userNote, 'Key takeaway: cache it');
    expect(storage.savedRows, hasLength(1));
    expect(storage.savedRows.single.id, saved.id);
    expect(find.text('Note saved'), findsOneWidget);
    // The button flips to the filled icon once a note exists.
    expect(find.byIcon(Icons.sticky_note_2), findsOneWidget);
  });
}
