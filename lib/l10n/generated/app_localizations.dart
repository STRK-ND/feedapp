import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Curated Feeds'**
  String get appTitle;

  /// No description provided for @sourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sourcesTitle;

  /// No description provided for @sourcesSubscribedLabel.
  ///
  /// In en, this message translates to:
  /// **'SUBSCRIBED'**
  String get sourcesSubscribedLabel;

  /// No description provided for @sourcesActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String sourcesActiveCount(int count);

  /// No description provided for @sourcesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'No sources yet. Pick from DISCOVER below.'**
  String get sourcesEmptyHint;

  /// No description provided for @sourcesDiscoverLabel.
  ///
  /// In en, this message translates to:
  /// **'DISCOVER'**
  String get sourcesDiscoverLabel;

  /// No description provided for @sourcesTapToAdd.
  ///
  /// In en, this message translates to:
  /// **'tap to add'**
  String get sourcesTapToAdd;

  /// No description provided for @sourcesAddFeedUrl.
  ///
  /// In en, this message translates to:
  /// **'ADD A FEED URL'**
  String get sourcesAddFeedUrl;

  /// No description provided for @sourcesAddCustomSemantic.
  ///
  /// In en, this message translates to:
  /// **'Add a custom RSS or Atom feed'**
  String get sourcesAddCustomSemantic;

  /// No description provided for @sourceUnsubscribedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get sourceUnsubscribedSubtitle;

  /// No description provided for @sourceUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count} unread'**
  String sourceUnreadCount(int count);

  /// No description provided for @unsubscribeTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe from {name}?'**
  String unsubscribeTitle(String name);

  /// No description provided for @unsubscribeBody.
  ///
  /// In en, this message translates to:
  /// **'Articles from this source will no longer appear in your feed.\n\nYou can re-subscribe any time.'**
  String get unsubscribeBody;

  /// No description provided for @removeSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeSourceTitle(String name);

  /// No description provided for @removeSourceBody.
  ///
  /// In en, this message translates to:
  /// **'Your feed will stop checking {url}.\n\nYou can add it back any time.'**
  String removeSourceBody(String url);

  /// No description provided for @dialogKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get dialogKeep;

  /// No description provided for @dialogUnsubscribe.
  ///
  /// In en, this message translates to:
  /// **'Unsubscribe'**
  String get dialogUnsubscribe;

  /// No description provided for @dialogRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get dialogRemove;

  /// No description provided for @addSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a source'**
  String get addSheetTitle;

  /// No description provided for @addSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Any public RSS or Atom feed.'**
  String get addSheetSubtitle;

  /// No description provided for @feedUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Feed URL'**
  String get feedUrlLabel;

  /// No description provided for @feedUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/feed.xml'**
  String get feedUrlHint;

  /// No description provided for @nameOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptionalLabel;

  /// No description provided for @addSourceCta.
  ///
  /// In en, this message translates to:
  /// **'Add source'**
  String get addSourceCta;

  /// No description provided for @invalidUrlError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid http(s) feed URL'**
  String get invalidUrlError;

  /// No description provided for @sourceAddedSnack.
  ///
  /// In en, this message translates to:
  /// **'Source added — pull to refresh your feed'**
  String get sourceAddedSnack;

  /// No description provided for @opmlFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large'**
  String get opmlFileTooLarge;

  /// No description provided for @opmlNoUrlsFound.
  ///
  /// In en, this message translates to:
  /// **'No feed URLs found in OPML file'**
  String get opmlNoUrlsFound;

  /// No description provided for @opmlNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Found {count} feed URLs but none match Curated Feeds sources. Only Curated Feeds sources are supported.'**
  String opmlNoMatches(int count);

  /// No description provided for @opmlImported.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} source(s)'**
  String opmlImported(int count);

  /// No description provided for @opmlImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t import that file. Make sure it\'s a valid OPML export.'**
  String get opmlImportFailed;

  /// No description provided for @opmlNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export — subscribe to a source first'**
  String get opmlNothingToExport;

  /// No description provided for @opmlExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t export subscriptions.'**
  String get opmlExportFailed;

  /// No description provided for @exportOpmlLabel.
  ///
  /// In en, this message translates to:
  /// **'Export OPML'**
  String get exportOpmlLabel;

  /// No description provided for @importOpmlLabel.
  ///
  /// In en, this message translates to:
  /// **'Import OPML'**
  String get importOpmlLabel;

  /// No description provided for @exportOpmlSemantic.
  ///
  /// In en, this message translates to:
  /// **'Export subscriptions as OPML'**
  String get exportOpmlSemantic;

  /// No description provided for @importOpmlSemantic.
  ///
  /// In en, this message translates to:
  /// **'Import OPML file'**
  String get importOpmlSemantic;

  /// No description provided for @sourceTileSemantic.
  ///
  /// In en, this message translates to:
  /// **'{name}. {subtitle}. Tap to open feed, long-press to unsubscribe.'**
  String sourceTileSemantic(String name, String subtitle);

  /// No description provided for @sourceSubscribedSemantic.
  ///
  /// In en, this message translates to:
  /// **'{name}. Subscribed. Tap to unsubscribe.'**
  String sourceSubscribedSemantic(String name);

  /// No description provided for @sourceNotSubscribedSemantic.
  ///
  /// In en, this message translates to:
  /// **'{name}. Tap to subscribe.'**
  String sourceNotSubscribedSemantic(String name);

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Curated Feeds Pro'**
  String get paywallTitle;

  /// No description provided for @paywallStoreUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store unavailable. Check your connection and Play Store.'**
  String get paywallStoreUnavailable;

  /// No description provided for @paywallProductMissing.
  ///
  /// In en, this message translates to:
  /// **'Product not found in the store yet.'**
  String get paywallProductMissing;

  /// No description provided for @retryCta.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryCta;

  /// No description provided for @paywallHeading.
  ///
  /// In en, this message translates to:
  /// **'Support Curated Feeds'**
  String get paywallHeading;

  /// No description provided for @paywallOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase, yours forever.'**
  String get paywallOneTime;

  /// No description provided for @buyOnce.
  ///
  /// In en, this message translates to:
  /// **'Buy once — {price}'**
  String buyOnce(String price);

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore purchase'**
  String get restorePurchase;

  /// No description provided for @proThanks.
  ///
  /// In en, this message translates to:
  /// **'You\'re Pro!'**
  String get proThanks;

  /// No description provided for @proThanksBody.
  ///
  /// In en, this message translates to:
  /// **'Thanks for supporting Curated Feeds.'**
  String get proThanksBody;

  /// No description provided for @navSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get navSaved;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// No description provided for @markAllReadSemantic.
  ///
  /// In en, this message translates to:
  /// **'Mark {count} unread articles as read'**
  String markAllReadSemantic(int count);

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Showing cached content.'**
  String get offlineBanner;

  /// No description provided for @refreshFailedFallback.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh feeds'**
  String get refreshFailedFallback;

  /// No description provided for @articleSavedSnack.
  ///
  /// In en, this message translates to:
  /// **'Article saved'**
  String get articleSavedSnack;

  /// No description provided for @articleMarkedReadSnack.
  ///
  /// In en, this message translates to:
  /// **'Article marked as read'**
  String get articleMarkedReadSnack;

  /// No description provided for @articleRemovedSnack.
  ///
  /// In en, this message translates to:
  /// **'Article removed from saved'**
  String get articleRemovedSnack;

  /// No description provided for @undoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoAction;

  /// No description provided for @restoredSnack.
  ///
  /// In en, this message translates to:
  /// **'Restored.'**
  String get restoredSnack;

  /// No description provided for @markAllReadFailedSnack.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t mark all read.'**
  String get markAllReadFailedSnack;

  /// No description provided for @markedAsReadSnack.
  ///
  /// In en, this message translates to:
  /// **'Marked {count, plural, one{1 article} other{{count} articles}} as read.'**
  String markedAsReadSnack(int count);

  /// No description provided for @freeSavedLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Free limit of {count} saved articles reached — Go Pro for unlimited saves'**
  String freeSavedLimitReached(int count);

  /// No description provided for @emptyFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'The day is quiet.'**
  String get emptyFeedTitle;

  /// No description provided for @savedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet.'**
  String get savedEmptyTitle;

  /// No description provided for @emptyFeedHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the refresh button to load articles'**
  String get emptyFeedHint;

  /// No description provided for @clearSearchCta.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchCta;

  /// No description provided for @refreshingBanner.
  ///
  /// In en, this message translates to:
  /// **'Refreshing feeds.'**
  String get refreshingBanner;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search articles, sources, or content...'**
  String get searchHint;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String searchNoResultsTitle(String query);

  /// No description provided for @searchResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} result} other{{count} results}} for \"{query}\"'**
  String searchResultsCount(int count, String query);

  /// No description provided for @noUnreadToMark.
  ///
  /// In en, this message translates to:
  /// **'No unread to mark as read'**
  String get noUnreadToMark;

  /// No description provided for @markAllAsReadAction.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllAsReadAction;

  /// No description provided for @switchToContinuousTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to continuous list'**
  String get switchToContinuousTooltip;

  /// No description provided for @switchToStackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch to card stack'**
  String get switchToStackTooltip;

  /// No description provided for @continuousModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Continuous'**
  String get continuousModeLabel;

  /// No description provided for @cardStackModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Card stack'**
  String get cardStackModeLabel;

  /// No description provided for @loadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loadingLabel;

  /// No description provided for @refreshFeedsLabel.
  ///
  /// In en, this message translates to:
  /// **'Refresh feeds'**
  String get refreshFeedsLabel;

  /// No description provided for @closeSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearchLabel;

  /// No description provided for @searchArticlesLabel.
  ///
  /// In en, this message translates to:
  /// **'Search articles'**
  String get searchArticlesLabel;

  /// No description provided for @moreOptionsLabel.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptionsLabel;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @sectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get sectionAppearance;

  /// No description provided for @showImagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Show Images'**
  String get showImagesTitle;

  /// No description provided for @showImagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Display article images in feed'**
  String get showImagesSubtitle;

  /// No description provided for @dataSaverTitle.
  ///
  /// In en, this message translates to:
  /// **'Data Saver'**
  String get dataSaverTitle;

  /// No description provided for @dataSaverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reduce data usage by limiting image quality'**
  String get dataSaverSubtitle;

  /// No description provided for @sectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get sectionNotifications;

  /// No description provided for @pushNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get pushNotificationsTitle;

  /// No description provided for @pushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications for new content'**
  String get pushNotificationsSubtitle;

  /// No description provided for @pushServerFailSnack.
  ///
  /// In en, this message translates to:
  /// **'Could not reach notification server - try again'**
  String get pushServerFailSnack;

  /// No description provided for @newArticlesTitle.
  ///
  /// In en, this message translates to:
  /// **'New Articles'**
  String get newArticlesTitle;

  /// No description provided for @newArticlesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notify when new articles are available'**
  String get newArticlesSubtitle;

  /// No description provided for @alertCategoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Alert categories'**
  String get alertCategoriesTitle;

  /// No description provided for @alertCategoriesAll.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get alertCategoriesAll;

  /// No description provided for @inAppNotifsTitle.
  ///
  /// In en, this message translates to:
  /// **'In-App Notifications'**
  String get inAppNotifsTitle;

  /// No description provided for @inAppNotifsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show notification banners inside the app'**
  String get inAppNotifsSubtitle;

  /// No description provided for @sectionFeedSettings.
  ///
  /// In en, this message translates to:
  /// **'Feed Settings'**
  String get sectionFeedSettings;

  /// No description provided for @autoRefreshTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto Refresh'**
  String get autoRefreshTitle;

  /// No description provided for @autoRefreshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically refresh feeds in background'**
  String get autoRefreshSubtitle;

  /// No description provided for @refreshIntervalTitle.
  ///
  /// In en, this message translates to:
  /// **'Refresh Interval'**
  String get refreshIntervalTitle;

  /// No description provided for @sectionSources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sectionSources;

  /// No description provided for @manageSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage sources'**
  String get manageSourcesTitle;

  /// No description provided for @manageSourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe, browse, and unsubscribe'**
  String get manageSourcesSubtitle;

  /// No description provided for @sectionReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get sectionReading;

  /// No description provided for @readerPrefsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reader preferences'**
  String get readerPrefsTitle;

  /// No description provided for @readerPrefsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tune in the article reader, any time'**
  String get readerPrefsSubtitle;

  /// No description provided for @bodyFontTitle.
  ///
  /// In en, this message translates to:
  /// **'Body font'**
  String get bodyFontTitle;

  /// No description provided for @lineHeightTitle.
  ///
  /// In en, this message translates to:
  /// **'Line height'**
  String get lineHeightTitle;

  /// No description provided for @fontSizeTitle.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSizeTitle;

  /// No description provided for @themeRowLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeRowLabel;

  /// No description provided for @themeAutoLabel.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get themeAutoLabel;

  /// No description provided for @bodyFontEyebrow.
  ///
  /// In en, this message translates to:
  /// **'BODY FONT'**
  String get bodyFontEyebrow;

  /// No description provided for @sectionEdition.
  ///
  /// In en, this message translates to:
  /// **'Edition'**
  String get sectionEdition;

  /// No description provided for @editionNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Edition Nº {number}'**
  String editionNumberLabel(String number);

  /// No description provided for @editionBumpsHint.
  ///
  /// In en, this message translates to:
  /// **'Bumps on every refresh.'**
  String get editionBumpsHint;

  /// No description provided for @sectionStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage & Data'**
  String get sectionStorage;

  /// No description provided for @cachedArticlesTitle.
  ///
  /// In en, this message translates to:
  /// **'Cached Articles'**
  String get cachedArticlesTitle;

  /// No description provided for @savedArticlesCountTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Articles'**
  String get savedArticlesCountTitle;

  /// No description provided for @clearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCacheTitle;

  /// No description provided for @clearCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove all cached data'**
  String get clearCacheSubtitle;

  /// No description provided for @clearCacheDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get clearCacheDialogTitle;

  /// No description provided for @clearCacheDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This will delete {count} cached articles. Saved articles are kept. This action cannot be undone.'**
  String clearCacheDialogBody(int count);

  /// No description provided for @dialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dialogCancel;

  /// No description provided for @dialogClearAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get dialogClearAction;

  /// No description provided for @dialogSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dialogSaveAction;

  /// No description provided for @cacheClearedSnack.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get cacheClearedSnack;

  /// No description provided for @sectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get sectionAbout;

  /// No description provided for @appVersionTitle.
  ///
  /// In en, this message translates to:
  /// **'App Version'**
  String get appVersionTitle;

  /// No description provided for @openSourceLicensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get openSourceLicensesTitle;

  /// No description provided for @openSourceLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View third-party licenses'**
  String get openSourceLicensesSubtitle;

  /// No description provided for @sectionSupport.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get sectionSupport;

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proBadge;

  /// No description provided for @supportAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Support the app'**
  String get supportAppTitle;

  /// No description provided for @thanksSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your support!'**
  String get thanksSupportSubtitle;

  /// No description provided for @supportOneTimeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase, yours forever'**
  String get supportOneTimeSubtitle;

  /// No description provided for @reportBugTitle.
  ///
  /// In en, this message translates to:
  /// **'Report bug / Feedback'**
  String get reportBugTitle;

  /// No description provided for @emailCopiedSnack.
  ///
  /// In en, this message translates to:
  /// **'Email address copied to clipboard'**
  String get emailCopiedSnack;

  /// No description provided for @obStep1Eyebrow.
  ///
  /// In en, this message translates to:
  /// **'PICK A ROOM'**
  String get obStep1Eyebrow;

  /// No description provided for @obStep1Title.
  ///
  /// In en, this message translates to:
  /// **'How should\nthis feel?'**
  String get obStep1Title;

  /// No description provided for @obStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Three rooms. Pick the one that\nmakes you want to settle in.'**
  String get obStep1Subtitle;

  /// No description provided for @roomPaperLabel.
  ///
  /// In en, this message translates to:
  /// **'PAPER'**
  String get roomPaperLabel;

  /// No description provided for @roomPaperDesc.
  ///
  /// In en, this message translates to:
  /// **'Daytime. Bright. Off-white stock.'**
  String get roomPaperDesc;

  /// No description provided for @roomLamplightLabel.
  ///
  /// In en, this message translates to:
  /// **'LAMPLIGHT'**
  String get roomLamplightLabel;

  /// No description provided for @roomLamplightDesc.
  ///
  /// In en, this message translates to:
  /// **'After dark. Warm amber. The default.'**
  String get roomLamplightDesc;

  /// No description provided for @roomSystemLabel.
  ///
  /// In en, this message translates to:
  /// **'FOLLOW YOUR PHONE'**
  String get roomSystemLabel;

  /// No description provided for @roomSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Switches with the system.'**
  String get roomSystemDesc;

  /// No description provided for @sampleHeading.
  ///
  /// In en, this message translates to:
  /// **'A heading that earns\nthe reader.'**
  String get sampleHeading;

  /// No description provided for @obStep2Eyebrow.
  ///
  /// In en, this message translates to:
  /// **'TUNE THE READING'**
  String get obStep2Eyebrow;

  /// No description provided for @obStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Make it\ncomfortable.'**
  String get obStep2Title;

  /// No description provided for @sampleSentence.
  ///
  /// In en, this message translates to:
  /// **'How a sentence reads at this size.'**
  String get sampleSentence;

  /// No description provided for @lineHeightExplainer.
  ///
  /// In en, this message translates to:
  /// **'Line-height is the breath between lines. Wider is calmer; tighter accelerates.'**
  String get lineHeightExplainer;

  /// No description provided for @fontSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'FONT SIZE'**
  String get fontSizeLabel;

  /// No description provided for @lineHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'LINE HEIGHT'**
  String get lineHeightLabel;

  /// No description provided for @typewriterDatelinesLabel.
  ///
  /// In en, this message translates to:
  /// **'TYPEWRITER DATELINES'**
  String get typewriterDatelinesLabel;

  /// No description provided for @typewriterDatelinesDesc.
  ///
  /// In en, this message translates to:
  /// **'Show dates and counts in JetBrains Mono.'**
  String get typewriterDatelinesDesc;

  /// No description provided for @obStep3Eyebrow.
  ///
  /// In en, this message translates to:
  /// **'PICK A FIRST SOURCE'**
  String get obStep3Eyebrow;

  /// No description provided for @obStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Start with one\nor twenty.'**
  String get obStep3Title;

  /// No description provided for @obStep3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'These are first-issue picks. You can change them any time from Settings.'**
  String get obStep3Subtitle;

  /// No description provided for @obContinueCta.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get obContinueCta;

  /// No description provided for @obAddAndContinueCta.
  ///
  /// In en, this message translates to:
  /// **'ADD {count}  ·  CONTINUE'**
  String obAddAndContinueCta(int count);

  /// No description provided for @obContinueWithoutCta.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE WITHOUT'**
  String get obContinueWithoutCta;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'A reading room.'**
  String get splashTagline;

  /// No description provided for @splashEditionLabel.
  ///
  /// In en, this message translates to:
  /// **'EDITION Nº {number}'**
  String splashEditionLabel(String number);

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailableTitle;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @releasedLabel.
  ///
  /// In en, this message translates to:
  /// **'Released: {date}'**
  String releasedLabel(String date);

  /// No description provided for @whatsNewLabel.
  ///
  /// In en, this message translates to:
  /// **'What\'s new:'**
  String get whatsNewLabel;

  /// No description provided for @ignoreDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Ignore this update?'**
  String get ignoreDialogTitle;

  /// No description provided for @ignoreDialogBody.
  ///
  /// In en, this message translates to:
  /// **'You won\'t be notified about version {version} again. You can still update later.'**
  String ignoreDialogBody(String version);

  /// No description provided for @ignoreAction.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignoreAction;

  /// No description provided for @skipVersionAction.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get skipVersionAction;

  /// No description provided for @openInBrowserAction.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get openInBrowserAction;

  /// No description provided for @failedOpenVisit.
  ///
  /// In en, this message translates to:
  /// **'Failed to open download. Please visit: {url}'**
  String failedOpenVisit(String url);

  /// No description provided for @recentlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Recently'**
  String get recentlyLabel;

  /// No description provided for @updateNowCta.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get updateNowCta;

  /// No description provided for @downloadingCta.
  ///
  /// In en, this message translates to:
  /// **'Downloading…'**
  String get downloadingCta;

  /// No description provided for @installingCta.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get installingCta;

  /// No description provided for @openingCta.
  ///
  /// In en, this message translates to:
  /// **'Opening…'**
  String get openingCta;

  /// No description provided for @tryAgainCta.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgainCta;

  /// No description provided for @updateFailedError.
  ///
  /// In en, this message translates to:
  /// **'Update failed. Try again.'**
  String get updateFailedError;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @upToDateMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re using the latest version!'**
  String get upToDateMessage;

  /// No description provided for @maxArticlesLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Articles'**
  String get maxArticlesLabel;

  /// No description provided for @loadingFullArticle.
  ///
  /// In en, this message translates to:
  /// **'Loading full article...'**
  String get loadingFullArticle;

  /// No description provided for @proThemeLocked.
  ///
  /// In en, this message translates to:
  /// **'{theme} is a Pro theme — Go Pro to unlock'**
  String proThemeLocked(String theme);

  /// No description provided for @savedEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe right on the feed to keep\narticles for later.'**
  String get savedEmptyHint;

  /// No description provided for @sectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get sectionAccount;

  /// No description provided for @accountSignedOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync your feeds, saves and settings'**
  String get accountSignedOutSubtitle;

  /// No description provided for @accountSyncSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Synced to your account'**
  String get accountSyncSubtitle;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync pauses until you sign back in. Data on this device stays.'**
  String get signOutBody;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOutConfirm;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your sources, saved stories and settings — on every device.'**
  String get loginSubtitle;

  /// No description provided for @loginGoogleCta.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginGoogleCta;

  /// No description provided for @loginEmailCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginEmailCta;

  /// No description provided for @loginRegisterCta.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginRegisterCta;

  /// No description provided for @loginToggleToRegister.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get loginToggleToRegister;

  /// No description provided for @loginToggleToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get loginToggleToSignIn;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordCta.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get resetPasswordCta;

  /// No description provided for @resetPasswordSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent'**
  String get resetPasswordSent;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Check your connection and try again.'**
  String get authErrorGeneric;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'That email address doesn\'t look right.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password.'**
  String get authErrorWrongPassword;

  /// No description provided for @authErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account with that email.'**
  String get authErrorUserNotFound;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account with that email already exists.'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again shortly.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network problem. Check your connection.'**
  String get authErrorNetwork;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
