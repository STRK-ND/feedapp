// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Curated Feeds';

  @override
  String get sourcesTitle => 'Sources';

  @override
  String get sourcesSubscribedLabel => 'SUBSCRIBED';

  @override
  String sourcesActiveCount(int count) {
    return '$count active';
  }

  @override
  String get sourcesEmptyHint => 'No sources yet. Pick from DISCOVER below.';

  @override
  String get sourcesDiscoverLabel => 'DISCOVER';

  @override
  String get sourcesTapToAdd => 'tap to add';

  @override
  String get sourcesAddFeedUrl => 'ADD A FEED URL';

  @override
  String get sourcesAddCustomSemantic => 'Add a custom RSS or Atom feed';

  @override
  String get sourceUnsubscribedSubtitle => 'All caught up';

  @override
  String sourceUnreadCount(int count) {
    return '$count unread';
  }

  @override
  String unsubscribeTitle(String name) {
    return 'Unsubscribe from $name?';
  }

  @override
  String get unsubscribeBody =>
      'Articles from this source will no longer appear in your feed.\n\nYou can re-subscribe any time.';

  @override
  String removeSourceTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String removeSourceBody(String url) {
    return 'Your feed will stop checking $url.\n\nYou can add it back any time.';
  }

  @override
  String get dialogKeep => 'Keep';

  @override
  String get dialogUnsubscribe => 'Unsubscribe';

  @override
  String get dialogRemove => 'Remove';

  @override
  String get addSheetTitle => 'Add a source';

  @override
  String get addSheetSubtitle => 'Any public RSS or Atom feed.';

  @override
  String get feedUrlLabel => 'Feed URL';

  @override
  String get feedUrlHint => 'https://example.com/feed.xml';

  @override
  String get nameOptionalLabel => 'Name (optional)';

  @override
  String get addSourceCta => 'Add source';

  @override
  String get invalidUrlError => 'Enter a valid http(s) feed URL';

  @override
  String get sourceAddedSnack => 'Source added — pull to refresh your feed';

  @override
  String get opmlFileTooLarge => 'File too large';

  @override
  String get opmlNoUrlsFound => 'No feed URLs found in OPML file';

  @override
  String opmlNoMatches(int count) {
    return 'Found $count feed URLs but none match Curated Feeds sources. Only Curated Feeds sources are supported.';
  }

  @override
  String opmlImported(int count) {
    return 'Imported $count source(s)';
  }

  @override
  String get opmlImportFailed =>
      'Couldn\'t import that file. Make sure it\'s a valid OPML export.';

  @override
  String get opmlNothingToExport =>
      'Nothing to export — subscribe to a source first';

  @override
  String get opmlExportFailed => 'Couldn\'t export subscriptions.';

  @override
  String get exportOpmlLabel => 'Export OPML';

  @override
  String get importOpmlLabel => 'Import OPML';

  @override
  String get exportOpmlSemantic => 'Export subscriptions as OPML';

  @override
  String get importOpmlSemantic => 'Import OPML file';

  @override
  String sourceTileSemantic(String name, String subtitle) {
    return '$name. $subtitle. Tap to open feed, long-press to unsubscribe.';
  }

  @override
  String sourceSubscribedSemantic(String name) {
    return '$name. Subscribed. Tap to unsubscribe.';
  }

  @override
  String sourceNotSubscribedSemantic(String name) {
    return '$name. Tap to subscribe.';
  }

  @override
  String get paywallTitle => 'Curated Feeds Pro';

  @override
  String get paywallStoreUnavailable =>
      'Store unavailable. Check your connection and Play Store.';

  @override
  String get paywallProductMissing => 'Product not found in the store yet.';

  @override
  String get retryCta => 'Retry';

  @override
  String get paywallHeading => 'Support Curated Feeds';

  @override
  String get paywallOneTime => 'One-time purchase, yours forever.';

  @override
  String buyOnce(String price) {
    return 'Buy once — $price';
  }

  @override
  String get restorePurchase => 'Restore purchase';

  @override
  String get proThanks => 'You\'re Pro!';

  @override
  String get proThanksBody => 'Thanks for supporting Curated Feeds.';

  @override
  String get navSaved => 'Saved';

  @override
  String get navSettings => 'Settings';

  @override
  String get navFeed => 'Feed';

  @override
  String markAllReadSemantic(int count) {
    return 'Mark $count unread articles as read';
  }

  @override
  String get offlineBanner => 'You are offline. Showing cached content.';

  @override
  String get refreshFailedFallback => 'Failed to refresh feeds';

  @override
  String get articleSavedSnack => 'Article saved';

  @override
  String get articleMarkedReadSnack => 'Article marked as read';

  @override
  String get articleRemovedSnack => 'Article removed from saved';

  @override
  String get undoAction => 'Undo';

  @override
  String get restoredSnack => 'Restored.';

  @override
  String get markAllReadFailedSnack => 'Couldn\'t mark all read.';

  @override
  String markedAsReadSnack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return 'Marked $_temp0 as read.';
  }

  @override
  String freeSavedLimitReached(int count) {
    return 'Free limit of $count saved articles reached — Go Pro for unlimited saves';
  }

  @override
  String get emptyFeedTitle => 'The day is quiet.';

  @override
  String get savedEmptyTitle => 'Nothing saved yet.';

  @override
  String get emptyFeedHint => 'Tap the refresh button to load articles';

  @override
  String get clearSearchCta => 'Clear search';

  @override
  String get refreshingBanner => 'Refreshing feeds.';

  @override
  String get searchHint => 'Search articles, sources, or content...';

  @override
  String searchNoResultsTitle(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String searchResultsCount(int count, String query) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '$count result',
    );
    return '$_temp0 for \"$query\"';
  }

  @override
  String get noUnreadToMark => 'No unread to mark as read';

  @override
  String get markAllAsReadAction => 'Mark all as read';

  @override
  String get switchToContinuousTooltip => 'Switch to continuous list';

  @override
  String get switchToStackTooltip => 'Switch to card stack';

  @override
  String get continuousModeLabel => 'Continuous';

  @override
  String get cardStackModeLabel => 'Card stack';

  @override
  String get loadingLabel => 'Loading';

  @override
  String get refreshFeedsLabel => 'Refresh feeds';

  @override
  String get closeSearchLabel => 'Close search';

  @override
  String get searchArticlesLabel => 'Search articles';

  @override
  String get moreOptionsLabel => 'More options';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get showImagesTitle => 'Show Images';

  @override
  String get showImagesSubtitle => 'Display article images in feed';

  @override
  String get dataSaverTitle => 'Data Saver';

  @override
  String get dataSaverSubtitle => 'Reduce data usage by limiting image quality';

  @override
  String get sectionNotifications => 'Notifications';

  @override
  String get pushNotificationsTitle => 'Push Notifications';

  @override
  String get pushNotificationsSubtitle =>
      'Receive notifications for new content';

  @override
  String get pushServerFailSnack =>
      'Could not reach notification server - try again';

  @override
  String get newArticlesTitle => 'New Articles';

  @override
  String get newArticlesSubtitle => 'Notify when new articles are available';

  @override
  String get alertCategoriesTitle => 'Alert categories';

  @override
  String get alertCategoriesAll => 'All categories';

  @override
  String get inAppNotifsTitle => 'In-App Notifications';

  @override
  String get inAppNotifsSubtitle => 'Show notification banners inside the app';

  @override
  String get sectionFeedSettings => 'Feed Settings';

  @override
  String get autoRefreshTitle => 'Auto Refresh';

  @override
  String get autoRefreshSubtitle => 'Automatically refresh feeds in background';

  @override
  String get refreshIntervalTitle => 'Refresh Interval';

  @override
  String get sectionSources => 'Sources';

  @override
  String get manageSourcesTitle => 'Manage sources';

  @override
  String get manageSourcesSubtitle => 'Subscribe, browse, and unsubscribe';

  @override
  String get sectionReading => 'Reading';

  @override
  String get readerPrefsTitle => 'Reader preferences';

  @override
  String get readerPrefsSubtitle => 'Tune in the article reader, any time';

  @override
  String get bodyFontTitle => 'Body font';

  @override
  String get lineHeightTitle => 'Line height';

  @override
  String get fontSizeTitle => 'Font size';

  @override
  String get themeRowLabel => 'Theme';

  @override
  String get themeAutoLabel => 'AUTO';

  @override
  String get bodyFontEyebrow => 'BODY FONT';

  @override
  String get sectionEdition => 'Edition';

  @override
  String editionNumberLabel(String number) {
    return 'Edition Nº $number';
  }

  @override
  String get editionBumpsHint => 'Bumps on every refresh.';

  @override
  String get sectionStorage => 'Storage & Data';

  @override
  String get cachedArticlesTitle => 'Cached Articles';

  @override
  String get savedArticlesCountTitle => 'Saved Articles';

  @override
  String get clearCacheTitle => 'Clear Cache';

  @override
  String get clearCacheSubtitle => 'Remove all cached data';

  @override
  String get clearCacheDialogTitle => 'Clear Cache';

  @override
  String clearCacheDialogBody(int count) {
    return 'This will delete $count cached articles. Saved articles are kept. This action cannot be undone.';
  }

  @override
  String get dialogCancel => 'Cancel';

  @override
  String get dialogClearAction => 'Clear';

  @override
  String get dialogSaveAction => 'Save';

  @override
  String get cacheClearedSnack => 'Cache cleared successfully';

  @override
  String get sectionAbout => 'About';

  @override
  String get appVersionTitle => 'App Version';

  @override
  String get openSourceLicensesTitle => 'Open Source Licenses';

  @override
  String get openSourceLicensesSubtitle => 'View third-party licenses';

  @override
  String get sectionSupport => 'Support';

  @override
  String get proBadge => 'Pro';

  @override
  String get supportAppTitle => 'Support the app';

  @override
  String get thanksSupportSubtitle => 'Thanks for your support!';

  @override
  String get supportOneTimeSubtitle => 'One-time purchase, yours forever';

  @override
  String get reportBugTitle => 'Report bug / Feedback';

  @override
  String get emailCopiedSnack => 'Email address copied to clipboard';

  @override
  String get obStep1Eyebrow => 'PICK A ROOM';

  @override
  String get obStep1Title => 'How should\nthis feel?';

  @override
  String get obStep1Subtitle =>
      'Three rooms. Pick the one that\nmakes you want to settle in.';

  @override
  String get roomPaperLabel => 'PAPER';

  @override
  String get roomPaperDesc => 'Daytime. Bright. Off-white stock.';

  @override
  String get roomLamplightLabel => 'LAMPLIGHT';

  @override
  String get roomLamplightDesc => 'After dark. Warm amber. The default.';

  @override
  String get roomSystemLabel => 'FOLLOW YOUR PHONE';

  @override
  String get roomSystemDesc => 'Switches with the system.';

  @override
  String get sampleHeading => 'A heading that earns\nthe reader.';

  @override
  String get obStep2Eyebrow => 'TUNE THE READING';

  @override
  String get obStep2Title => 'Make it\ncomfortable.';

  @override
  String get sampleSentence => 'How a sentence reads at this size.';

  @override
  String get lineHeightExplainer =>
      'Line-height is the breath between lines. Wider is calmer; tighter accelerates.';

  @override
  String get fontSizeLabel => 'FONT SIZE';

  @override
  String get lineHeightLabel => 'LINE HEIGHT';

  @override
  String get typewriterDatelinesLabel => 'TYPEWRITER DATELINES';

  @override
  String get typewriterDatelinesDesc =>
      'Show dates and counts in JetBrains Mono.';

  @override
  String get obStep3Eyebrow => 'PICK A FIRST SOURCE';

  @override
  String get obStep3Title => 'Start with one\nor twenty.';

  @override
  String get obStep3Subtitle =>
      'These are first-issue picks. You can change them any time from Settings.';

  @override
  String get obContinueCta => 'CONTINUE';

  @override
  String obAddAndContinueCta(int count) {
    return 'ADD $count  ·  CONTINUE';
  }

  @override
  String get obContinueWithoutCta => 'CONTINUE WITHOUT';

  @override
  String get splashTagline => 'A reading room.';

  @override
  String splashEditionLabel(String number) {
    return 'EDITION Nº $number';
  }

  @override
  String get updateAvailableTitle => 'Update Available';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String releasedLabel(String date) {
    return 'Released: $date';
  }

  @override
  String get whatsNewLabel => 'What\'s new:';

  @override
  String get ignoreDialogTitle => 'Ignore this update?';

  @override
  String ignoreDialogBody(String version) {
    return 'You won\'t be notified about version $version again. You can still update later.';
  }

  @override
  String get ignoreAction => 'Ignore';

  @override
  String get skipVersionAction => 'Skip this version';

  @override
  String get openInBrowserAction => 'Open in browser';

  @override
  String failedOpenVisit(String url) {
    return 'Failed to open download. Please visit: $url';
  }

  @override
  String get recentlyLabel => 'Recently';

  @override
  String get updateNowCta => 'Update Now';

  @override
  String get downloadingCta => 'Downloading…';

  @override
  String get installingCta => 'Installing…';

  @override
  String get openingCta => 'Opening…';

  @override
  String get tryAgainCta => 'Try again';

  @override
  String get updateFailedError => 'Update failed. Try again.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get upToDateMessage => 'You\'re using the latest version!';

  @override
  String get maxArticlesLabel => 'Max Articles';

  @override
  String get loadingFullArticle => 'Loading full article...';

  @override
  String proThemeLocked(String theme) {
    return '$theme is a Pro theme — Go Pro to unlock';
  }

  @override
  String get savedEmptyHint =>
      'Swipe right on the feed to keep\narticles for later.';

  @override
  String get sectionAccount => 'Account';

  @override
  String get accountSignedOutSubtitle => 'Sync your feeds, saves and settings';

  @override
  String get accountSyncSubtitle => 'Synced to your account';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutBody =>
      'Cloud sync pauses until you sign back in. Data on this device stays.';

  @override
  String get signOutConfirm => 'Sign out';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get loginSubtitle =>
      'Your sources, saved stories and settings — on every device.';

  @override
  String get loginGoogleCta => 'Continue with Google';

  @override
  String get loginEmailCta => 'Sign in';

  @override
  String get loginRegisterCta => 'Create account';

  @override
  String get loginToggleToRegister => 'New here? Create an account';

  @override
  String get loginToggleToSignIn => 'Already have an account? Sign in';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetPasswordCta => 'Send reset link';

  @override
  String get resetPasswordSent => 'Password reset email sent';

  @override
  String get authErrorGeneric =>
      'Couldn\'t sign in. Check your connection and try again.';

  @override
  String get authErrorInvalidEmail => 'That email address doesn\'t look right.';

  @override
  String get authErrorWrongPassword => 'Wrong email or password.';

  @override
  String get authErrorUserNotFound => 'No account with that email.';

  @override
  String get authErrorEmailInUse =>
      'An account with that email already exists.';

  @override
  String get authErrorWeakPassword => 'Password must be at least 6 characters.';

  @override
  String get authErrorTooManyRequests =>
      'Too many attempts. Try again shortly.';

  @override
  String get authErrorNetwork => 'Network problem. Check your connection.';
}
