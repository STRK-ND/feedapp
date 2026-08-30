// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'क्यूरेटेड फीड्स';

  @override
  String get sourcesTitle => 'स्रोत';

  @override
  String get sourcesSubscribedLabel => 'सदस्यता ली गई';

  @override
  String sourcesActiveCount(int count) {
    return '$count सक्रिय';
  }

  @override
  String get sourcesEmptyHint =>
      'अभी कोई स्रोत नहीं है। नीचे DISCOVER से चुनें।';

  @override
  String get sourcesDiscoverLabel => 'खोजें';

  @override
  String get sourcesTapToAdd => 'जोड़ने के लिए टैप करें';

  @override
  String get sourcesAddFeedUrl => 'फ़ीड URL जोड़ें';

  @override
  String get sourcesAddCustomSemantic => 'कोई RSS या Atom फ़ीड जोड़ें';

  @override
  String get sourceUnsubscribedSubtitle => 'सब पढ़ लिया';

  @override
  String sourceUnreadCount(int count) {
    return '$count अपठित';
  }

  @override
  String unsubscribeTitle(String name) {
    return '$name की सदस्यता रद्द करें?';
  }

  @override
  String get unsubscribeBody =>
      'इस स्रोत के लेख अब आपकी फ़ीड में नहीं दिखेंगे।\n\nआप कभी भी दोबारा सदस्यता ले सकते हैं।';

  @override
  String removeSourceTitle(String name) {
    return '$name हटाएँ?';
  }

  @override
  String removeSourceBody(String url) {
    return 'आपकी फ़ीड $url की जाँच करना बंद कर देगी।\n\nआप इसे कभी भी वापस जोड़ सकते हैं।';
  }

  @override
  String get dialogKeep => 'रखें';

  @override
  String get dialogUnsubscribe => 'सदस्यता रद्द करें';

  @override
  String get dialogRemove => 'हटाएँ';

  @override
  String get addSheetTitle => 'स्रोत जोड़ें';

  @override
  String get addSheetSubtitle => 'कोई भी सार्वजनिक RSS या Atom फ़ीड।';

  @override
  String get feedUrlLabel => 'फ़ीड URL';

  @override
  String get feedUrlHint => 'https://example.com/feed.xml';

  @override
  String get nameOptionalLabel => 'नाम (वैकल्पिक)';

  @override
  String get addSourceCta => 'स्रोत जोड़ें';

  @override
  String get invalidUrlError => 'मान्य http(s) फ़ीड URL दर्ज करें';

  @override
  String get sourceAddedSnack =>
      'स्रोत जोड़ा गया — फ़ीड रिफ्रेश करने के लिए नीचे खींचें';

  @override
  String get opmlFileTooLarge => 'फ़ाइल बहुत बड़ी है';

  @override
  String get opmlNoUrlsFound => 'OPML फ़ाइल में कोई फ़ीड URL नहीं मिला';

  @override
  String opmlNoMatches(int count) {
    return '$count फ़ीड URL मिले, पर कोई Curated Feeds स्रोत से नहीं मिलता। केवल Curated Feeds स्रोत समर्थित हैं।';
  }

  @override
  String opmlImported(int count) {
    return '$count स्रोत आयात किए गए';
  }

  @override
  String get opmlImportFailed =>
      'यह फ़ाइल आयात नहीं हो सकी। कृपया मान्य OPML एक्सपोर्ट चुनें।';

  @override
  String get opmlNothingToExport =>
      'निर्यात करने के लिए कुछ नहीं — पहले किसी स्रोत की सदस्यता लें';

  @override
  String get opmlExportFailed => 'सदस्यताएँ निर्यात नहीं हो सकीं।';

  @override
  String get exportOpmlLabel => 'OPML निर्यात';

  @override
  String get importOpmlLabel => 'OPML आयात';

  @override
  String get exportOpmlSemantic => 'सदस्यताएँ OPML के रूप में निर्यात करें';

  @override
  String get importOpmlSemantic => 'OPML फ़ाइल आयात करें';

  @override
  String sourceTileSemantic(String name, String subtitle) {
    return '$name. $subtitle. फ़ीड खोलने के लिए टैप करें, सदस्यता रद्द करने के लिए देर तक दबाएँ।';
  }

  @override
  String sourceSubscribedSemantic(String name) {
    return '$name. सदस्यता ली गई। रद्द करने के लिए टैप करें।';
  }

  @override
  String sourceNotSubscribedSemantic(String name) {
    return '$name. सदस्यता लेने के लिए टैप करें।';
  }

  @override
  String get paywallTitle => 'Curated Feeds Pro';

  @override
  String get paywallStoreUnavailable =>
      'स्टोर उपलब्ध नहीं है। अपना कनेक्शन और Play Store जाँचें।';

  @override
  String get paywallProductMissing => 'उत्पाद अभी स्टोर में नहीं मिला।';

  @override
  String get retryCta => 'पुनः प्रयास';

  @override
  String get paywallHeading => 'Curated Feeds को सहयोग दें';

  @override
  String get paywallOneTime => 'एक बार ख़रीदें, हमेशा के लिए आपका।';

  @override
  String buyOnce(String price) {
    return 'एक बार ख़रीदें — $price';
  }

  @override
  String get restorePurchase => 'ख़रीद पुनर्स्थापित करें';

  @override
  String get proThanks => 'आप Pro हैं!';

  @override
  String get proThanksBody => 'Curated Feeds को सहयोग देने के लिए धन्यवाद।';

  @override
  String get navSaved => 'सेव किए गए';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get navFeed => 'फ़ीड';

  @override
  String markAllReadSemantic(int count) {
    return '$count अपठित लेख पढ़ा हुआ चिह्नित करें';
  }

  @override
  String get offlineBanner => 'आप ऑफ़लाइन हैं। सेव की गई सामग्री दिखा रहे हैं।';

  @override
  String get refreshFailedFallback => 'फ़ीड रिफ्रेश करने में विफल';

  @override
  String get articleSavedSnack => 'लेख सेव हो गया';

  @override
  String get articleMarkedReadSnack => 'लेख पढ़ा हुआ चिह्नित हुआ';

  @override
  String get articleRemovedSnack => 'लेख सेव से हटा दिया गया';

  @override
  String get undoAction => 'पूर्ववत';

  @override
  String get restoredSnack => 'पूर्ववत हो गया।';

  @override
  String get markAllReadFailedSnack => 'सभी को पढ़ा हुआ चिह्नित नहीं कर सके।';

  @override
  String markedAsReadSnack(int count) {
    return '$count लेख पढ़ा हुआ चिह्नित किए गए।';
  }

  @override
  String freeSavedLimitReached(int count) {
    return 'सेव किए गए $count लेखों की मुफ़्त सीमा पूरी — unlimited सेव के लिए Pro लें';
  }

  @override
  String get emptyFeedTitle => 'आज दिन सुनसान है।';

  @override
  String get savedEmptyTitle => 'अभी कुछ सेव नहीं है।';

  @override
  String get emptyFeedHint => 'लेख लोड करने के लिए रिफ्रेश बटन दबाएँ';

  @override
  String get clearSearchCta => 'खोज साफ़ करें';

  @override
  String get refreshingBanner => 'फ़ीड रिफ्रेश हो रही है।';

  @override
  String get searchHint => 'लेख, स्रोत या सामग्री खोजें...';

  @override
  String searchNoResultsTitle(String query) {
    return '\"$query\" के लिए कोई परिणाम नहीं';
  }

  @override
  String searchResultsCount(int count, String query) {
    return '\"$query\" के लिए $count परिणाम';
  }

  @override
  String get noUnreadToMark => 'पढ़ा हुआ चिह्नित करने के लिए कुछ अपठित नहीं';

  @override
  String get markAllAsReadAction => 'सभी को पढ़ा हुआ चिह्नित करें';

  @override
  String get switchToContinuousTooltip => 'सतत सूची पर बदलें';

  @override
  String get switchToStackTooltip => 'कार्ड स्टैक पर बदलें';

  @override
  String get continuousModeLabel => 'सतत';

  @override
  String get cardStackModeLabel => 'कार्ड स्टैक';

  @override
  String get loadingLabel => 'लोड हो रहा है';

  @override
  String get refreshFeedsLabel => 'फ़ीड रिफ्रेश करें';

  @override
  String get closeSearchLabel => 'खोज बंद करें';

  @override
  String get searchArticlesLabel => 'लेख खोजें';

  @override
  String get moreOptionsLabel => 'और विकल्प';

  @override
  String get settingsTitle => 'सेटिंग्स';

  @override
  String get sectionAppearance => 'रूप-रंग';

  @override
  String get showImagesTitle => 'चित्र दिखाएँ';

  @override
  String get showImagesSubtitle => 'फ़ीड में लेख के चित्र दिखाएँ';

  @override
  String get dataSaverTitle => 'डेटा सेवर';

  @override
  String get dataSaverSubtitle => 'चित्र गुणवत्ता सीमित करके डेटा बचाएँ';

  @override
  String get sectionNotifications => 'सूचनाएँ';

  @override
  String get pushNotificationsTitle => 'पुश सूचनाएँ';

  @override
  String get pushNotificationsSubtitle => 'नई सामग्री की सूचनाएँ पाएँ';

  @override
  String get pushServerFailSnack =>
      'सूचना सर्वर से जुड़ नहीं पाए — फिर प्रयास करें';

  @override
  String get newArticlesTitle => 'नए लेख';

  @override
  String get newArticlesSubtitle => 'नए लेख मिलने पर सूचित करें';

  @override
  String get alertCategoriesTitle => 'अलर्ट श्रेणियाँ';

  @override
  String get alertCategoriesAll => 'सभी श्रेणियाँ';

  @override
  String get inAppNotifsTitle => 'इन-ऐप सूचनाएँ';

  @override
  String get inAppNotifsSubtitle => 'ऐप के भीतर बैनर सूचनाएँ दिखाएँ';

  @override
  String get sectionFeedSettings => 'फ़ीड सेटिंग्स';

  @override
  String get autoRefreshTitle => 'ऑटो रिफ्रेश';

  @override
  String get autoRefreshSubtitle => 'बैकग्राउंड में फ़ीड अपने-आप रिफ्रेश करें';

  @override
  String get refreshIntervalTitle => 'रिफ्रेश अंतराल';

  @override
  String get sectionSources => 'स्रोत';

  @override
  String get manageSourcesTitle => 'स्रोत प्रबंधित करें';

  @override
  String get manageSourcesSubtitle => 'सदस्यता लें, ब्राउ़ज़ करें, हटाएँ';

  @override
  String get sectionReading => 'पढ़ना';

  @override
  String get readerPrefsTitle => 'रीडर प्राथमिकताएँ';

  @override
  String get readerPrefsSubtitle => 'लेख रीडर में कभी भी सुझाएँ';

  @override
  String get bodyFontTitle => 'बॉडी फ़ॉन्ट';

  @override
  String get lineHeightTitle => 'पंक्ति ऊँचाई';

  @override
  String get fontSizeTitle => 'फ़ॉन्ट आकार';

  @override
  String get themeRowLabel => 'थीम';

  @override
  String get themeAutoLabel => 'ऑटो';

  @override
  String get bodyFontEyebrow => 'बॉडी फ़ॉन्ट';

  @override
  String get sectionEdition => 'अंक';

  @override
  String editionNumberLabel(String number) {
    return 'अंक Nº $number';
  }

  @override
  String get editionBumpsHint => 'हर रिफ्रेश पर बढ़ता है।';

  @override
  String get sectionStorage => 'भंडारण और डेटा';

  @override
  String get cachedArticlesTitle => 'कैश किए लेख';

  @override
  String get savedArticlesCountTitle => 'सेव किए लेख';

  @override
  String get clearCacheTitle => 'कैश साफ़ करें';

  @override
  String get clearCacheSubtitle => 'सभी कैश डेटा हटाएँ';

  @override
  String get clearCacheDialogTitle => 'कैश साफ़ करें';

  @override
  String clearCacheDialogBody(int count) {
    return '$count कैश लेख हट जाएँगे। सेव किए गए लेख सुरक्षित रहते हैं। इसे वापस नहीं किया जा सकता।';
  }

  @override
  String get dialogCancel => 'रद्द करें';

  @override
  String get dialogClearAction => 'साफ़ करें';

  @override
  String get dialogSaveAction => 'सेव करें';

  @override
  String get cacheClearedSnack => 'कैश सफलतापूर्वक साफ़ हुआ';

  @override
  String get sectionAbout => 'परिचय';

  @override
  String get appVersionTitle => 'ऐप संस्करण';

  @override
  String get openSourceLicensesTitle => 'ओपन सोर्स लाइसेंस';

  @override
  String get openSourceLicensesSubtitle => 'थर्ड-पार्टी लाइसेंस देखें';

  @override
  String get sectionSupport => 'सहयोग';

  @override
  String get proBadge => 'Pro';

  @override
  String get supportAppTitle => 'ऐप को सहयोग दें';

  @override
  String get thanksSupportSubtitle => 'आपके सहयोग के लिए धन्यवाद!';

  @override
  String get supportOneTimeSubtitle => 'एक बार ख़रीदें, हमेशा के लिए आपका';

  @override
  String get reportBugTitle => 'बग / फ़ीडबैक भेजें';

  @override
  String get emailCopiedSnack => 'ईमेल पता क्लिपबोर्ड पर कॉपी हुआ';

  @override
  String get obStep1Eyebrow => 'कमरा चुनें';

  @override
  String get obStep1Title => 'यह कैसा\nमहसूस हो?';

  @override
  String get obStep1Subtitle => 'तीन कमरे। वह चुनें जहाँ\nआप बसना चाहें।';

  @override
  String get roomPaperLabel => 'PAPER';

  @override
  String get roomPaperDesc => 'दिन का उजाला। रोशन। ऑफ़-वाइट काग़ज़।';

  @override
  String get roomLamplightLabel => 'LAMPLIGHT';

  @override
  String get roomLamplightDesc => 'रात के बाद। गर्म एंबर। मूल विकल्प।';

  @override
  String get roomSystemLabel => 'PHONE का पालन करें';

  @override
  String get roomSystemDesc => 'सिस्टम के साथ बदलता है।';

  @override
  String get sampleHeading => 'ऐसा शीर्षक जो\nपढ़ने के लायक हो।';

  @override
  String get obStep2Eyebrow => 'पढ़ाई सुझाएँ';

  @override
  String get obStep2Title => 'इसे\nआरामदायक बनाएँ।';

  @override
  String get sampleSentence => 'इस आकार में वाक्य कैसा पढ़ा जाता है।';

  @override
  String get lineHeightExplainer =>
      'पंक्ति-ऊँचाई पंकतियों के बीच साँस है। चौड़ी = शांत; तंग = तेज़।';

  @override
  String get fontSizeLabel => 'फ़ॉन्ट आकार';

  @override
  String get lineHeightLabel => 'पंक्ति ऊँचाई';

  @override
  String get typewriterDatelinesLabel => 'टाइपराइटर डेटलाइन';

  @override
  String get typewriterDatelinesDesc =>
      'तारीख़ें और गिनती JetBrains Mono में दिखाएँ।';

  @override
  String get obStep3Eyebrow => 'पहला स्रोत चुनें';

  @override
  String get obStep3Title => 'एक से\nबीस तक।';

  @override
  String get obStep3Subtitle =>
      'ये पहले अंक के चयन हैं। Settings से कभी भी बदलें।';

  @override
  String get obContinueCta => 'आगे बढ़ें';

  @override
  String obAddAndContinueCta(int count) {
    return '$count जोड़ें  ·  आगे बढ़ें';
  }

  @override
  String get obContinueWithoutCta => 'बिना जोड़े आगे बढ़ें';

  @override
  String get splashTagline => 'एक पठन-कक्ष।';

  @override
  String splashEditionLabel(String number) {
    return 'अंक Nº $number';
  }

  @override
  String get updateAvailableTitle => 'अपडेट उपलब्ध';

  @override
  String versionLabel(String version) {
    return 'संस्करण $version';
  }

  @override
  String releasedLabel(String date) {
    return 'जारी: $date';
  }

  @override
  String get whatsNewLabel => 'नया क्या:';

  @override
  String get ignoreDialogTitle => 'यह अपडेट छोड़ें?';

  @override
  String ignoreDialogBody(String version) {
    return 'संस्करण $version के लिए फिर सूचना नहीं मिलेगी। आप बाद में भी अपडेट कर सकते हैं।';
  }

  @override
  String get ignoreAction => 'छोड़ें';

  @override
  String get skipVersionAction => 'यह संस्करण छोड़ें';

  @override
  String get openInBrowserAction => 'ब्राउ़ज़र में खोलें';

  @override
  String failedOpenVisit(String url) {
    return 'डाउनलोड नहीं खुला। यहाँ जाएँ: $url';
  }

  @override
  String get recentlyLabel => 'हाल ही में';

  @override
  String get updateNowCta => 'अभी अपडेट करें';

  @override
  String get downloadingCta => 'डाउनलोड हो रहा है…';

  @override
  String get installingCta => 'इंस्टॉल हो रहा है…';

  @override
  String get openingCta => 'खुल रहा है…';

  @override
  String get tryAgainCta => 'फिर प्रयास करें';

  @override
  String get updateFailedError => 'अपडेट विफल। फिर प्रयास करें।';

  @override
  String get checkForUpdates => 'अपडेट के लिए जाँचें';

  @override
  String get upToDateMessage => 'आप नवीनतम संस्करण इस्तेमाल कर रहे हैं!';

  @override
  String get maxArticlesLabel => 'अधिकतम लेख';

  @override
  String get loadingFullArticle => 'पूरा लेख लोड हो रहा है...';

  @override
  String proThemeLocked(String theme) {
    return '$theme एक Pro थीम है — Pro लेकर खोलें';
  }

  @override
  String get savedEmptyHint =>
      'बाद के लिए लेख रखने हेतु फ़ीड में\nदाईं ओर स्वाइप करें।';

  @override
  String get sectionAccount => 'खाता';

  @override
  String get accountSignedOutSubtitle => 'अपने फ़ीड, सेव और सेटिंग्स सिंक करें';

  @override
  String get accountSyncSubtitle => 'आपके खाते से सिंक हो रहा है';

  @override
  String get accountSignOut => 'साइन आउट';

  @override
  String get signOutTitle => 'साइन आउट करें?';

  @override
  String get signOutBody =>
      'दोबारा साइन इन तक क्लाउड सिंक रुक जाएगा। इस डिवाइस का डेटा सुरक्षित रहता है।';

  @override
  String get signOutConfirm => 'साइन आउट';

  @override
  String get loginTitle => 'साइन इन';

  @override
  String get loginSubtitle =>
      'आपके स्रोत, सेव किए लेख और सेटिंग्स — हर डिवाइस पर।';

  @override
  String get loginGoogleCta => 'Google से जारी रखें';

  @override
  String get loginEmailCta => 'साइन इन';

  @override
  String get loginRegisterCta => 'खाता बनाएँ';

  @override
  String get loginToggleToRegister => 'नए हैं? खाता बनाएँ';

  @override
  String get loginToggleToSignIn => 'पहले से खाता है? साइन इन करें';

  @override
  String get emailLabel => 'ईमेल';

  @override
  String get passwordLabel => 'पासवर्ड';

  @override
  String get forgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get resetPasswordTitle => 'पासवर्ड रीसेट करें';

  @override
  String get resetPasswordCta => 'रीसेट लिंक भेजें';

  @override
  String get resetPasswordSent => 'पासवर्ड रीसेट ईमेल भेजा गया';

  @override
  String get authErrorGeneric =>
      'साइन इन नहीं हुआ। कनेक्शन जाँचें और फिर प्रयास करें।';

  @override
  String get authErrorInvalidEmail => 'यह ईमेल पता सही नहीं लगता।';

  @override
  String get authErrorWrongPassword => 'ईमेल या पासवर्ड ग़लत है।';

  @override
  String get authErrorUserNotFound => 'उस ईमेल से कोई खाता नहीं है।';

  @override
  String get authErrorEmailInUse => 'उस ईमेल से खाता पहले से मौजूद है।';

  @override
  String get authErrorWeakPassword => 'पासवर्ड कम से कम 6 अक्षरों का हो।';

  @override
  String get authErrorTooManyRequests =>
      'बहुत अधिक प्रयास। थोड़ी देर बाद कोशिश करें।';

  @override
  String get authErrorNetwork => 'नेटवर्क समस्या। कनेक्शन जाँचें।';
}
