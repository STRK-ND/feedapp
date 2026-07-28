/// SettingsNotifier — owns app preferences, persists to SettingsService,
/// and notifies listeners on every change. The single write-path for
/// settings in the app; UI must call `notifier.setX(...)` instead of
/// going directly to SettingsService.
///
/// Lifecycle: constructed once at app start (see CuratedFeedsApp).
/// `loadSettings()` is called once, then setters handle persistence
/// + notify themselves.
library;

import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../utils/reader_theme.dart';

class SettingsNotifier extends ChangeNotifier {
  final SettingsService _settingsService;

  // ----- Visual / data preferences (pre-existing fields) -----
  bool _showImages = true;
  bool _dataSaverMode = false;
  bool _autoRefresh = true;
  int _refreshInterval = 30;
  int _maxArticles = 500;

  // ----- Reading preferences (added in the redesign pass) -----
  ThemeMode _themeMode = ThemeMode.system;
  ReaderTheme _readerTheme = ReaderTheme.defaultTheme;
  double _fontSize = 16;
  double _lineHeight = 1.6;
  bool _monoDatelines = true;
  bool _widenMeasure = false;
  String _bodyFont = 'dm';

  // ----- Feed / edition -----
  String _viewMode = 'stack'; // 'stack' | 'continuous'
  int _edition = 1;

  // ----- Monetization -----
  bool _isPro = false;

  SettingsNotifier(this._settingsService);

  // Getters
  bool get showImages => _showImages;
  bool get dataSaverMode => _dataSaverMode;
  bool get autoRefresh => _autoRefresh;
  int get refreshInterval => _refreshInterval;
  int get maxArticles => _maxArticles;
  int get imageMaxWidth => _dataSaverMode ? 400 : 800;

  ThemeMode get themeMode => _themeMode;
  ReaderTheme get readerTheme => _readerTheme;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  bool get monoDatelines => _monoDatelines;
  bool get widenMeasure => _widenMeasure;
  String get bodyFont => _bodyFont;
  String get viewMode => _viewMode;
  int get edition => _edition;
  bool get isPro => _isPro;

  ReadingPreferences get readingPrefs => ReadingPreferences(
        theme: _readerTheme,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        monoDatelines: _monoDatelines,
        widenMeasure: _widenMeasure,
        bodyFont: _bodyFont,
      );

  // =========================================================================
  //  Load — called once at app start. Re-load after importing storage.
  // =========================================================================

  Future<void> loadSettings() async {
    await _settingsService.initializeDefaults();

    final results = await Future.wait([
      _settingsService.getShowImages(),
      _settingsService.getDataSaverMode(),
      _settingsService.getAutoRefresh(),
      _settingsService.getRefreshInterval(),
      _settingsService.getMaxArticles(),
      _settingsService.getThemeMode(),
      _settingsService.getReaderTheme(),
      _settingsService.getReaderFontSize(),
      _settingsService.getReaderLineHeight(),
      _settingsService.getMonoDatelinesEnabled(),
      _settingsService.getWidenMeasure(),
      _settingsService.getBodyFont(),
      _settingsService.getFeedViewMode(),
      _settingsService.getEditionNumber(),
      _settingsService.getIsPro(),
    ]);

    _showImages = results[0] as bool;
    _dataSaverMode = results[1] as bool;
    _autoRefresh = results[2] as bool;
    _refreshInterval = results[3] as int;
    _maxArticles = results[4] as int;
    _themeMode = results[5] as ThemeMode;
    _readerTheme = results[6] as ReaderTheme;
    _fontSize = results[7] as double;
    _lineHeight = results[8] as double;
    _monoDatelines = results[9] as bool;
    _widenMeasure = results[10] as bool;
    _bodyFont = results[11] as String;
    _viewMode = results[12] as String;
    _edition = results[13] as int;
    _isPro = results[14] as bool;

    try {
      notifyListeners();
    } catch (_) {
      // Ignore if disposed during async gap.
    }
  }

  // =========================================================================
  //  Visual / data preferences (existing API — kept for compatibility)
  // =========================================================================

  Future<void> setShowImages(bool value) async {
    _showImages = value;
    await _settingsService.setShowImages(value);
    notifyListeners();
  }

  Future<void> setDataSaverMode(bool value) async {
    _dataSaverMode = value;
    await _settingsService.setDataSaverMode(value);
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool value) async {
    _autoRefresh = value;
    await _settingsService.setAutoRefresh(value);
    notifyListeners();
  }

  Future<void> setRefreshInterval(int value) async {
    _refreshInterval = value;
    await _settingsService.setRefreshInterval(value);
    notifyListeners();
  }

  Future<void> setMaxArticles(int value) async {
    _maxArticles = value;
    await _settingsService.setMaxArticles(value);
    notifyListeners();
  }

  // =========================================================================
  //  New — sole write-path for reading prefs, theme, view mode, edition.
  // =========================================================================

  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await _settingsService.setThemeMode(value);
    notifyListeners();
  }

  Future<void> setReaderTheme(ReaderTheme value) async {
    _readerTheme = value;
    await _settingsService.setReaderTheme(value);
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    _fontSize = value;
    await _settingsService.setReaderFontSize(value);
    notifyListeners();
  }

  Future<void> setLineHeight(double value) async {
    _lineHeight = value;
    await _settingsService.setReaderLineHeight(value);
    notifyListeners();
  }

  Future<void> setMonoDatelines(bool value) async {
    _monoDatelines = value;
    await _settingsService.setMonoDatelinesEnabled(value);
    notifyListeners();
  }

  Future<void> setWidenMeasure(bool value) async {
    _widenMeasure = value;
    await _settingsService.setWidenMeasure(value);
    notifyListeners();
  }

  Future<void> setBodyFont(String value) async {
    _bodyFont = value;
    await _settingsService.setBodyFont(value);
    notifyListeners();
  }

  Future<void> setViewMode(String value) async {
    if (value == 'stack' || value == 'continuous') {
      _viewMode = value;
      await _settingsService.setFeedViewMode(value);
      notifyListeners();
    }
  }

  /// Bump the edition counter (called on successful refresh).
  /// Writes the new value through SettingsService, mirrors locally,
  /// notifies. Returns the new edition number.
  Future<int> bumpEdition() async {
    final next = await _settingsService.bumpEditionNumber();
    _edition = next;
    notifyListeners();
    return next;
  }

  Future<void> setIsPro(bool value) async {
    _isPro = value;
    await _settingsService.setIsPro(value);
    notifyListeners();
  }

  /// Reload a single field from the disk and notify — useful when an
  /// out-of-band write path (legacy code) flipped something we don't
  /// know about.
  Future<void> reloadFromDisk() async {
    await loadSettings();
  }
}
