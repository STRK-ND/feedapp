import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/reader_theme.dart';
import 'rss_feed_service.dart';

/// App Settings Service - manages all app preferences using SharedPreferences
class SettingsService {
  late SharedPreferences _prefs;
  Future<SharedPreferences>? _initFuture;

  /// Initialize SharedPreferences
  Future<void> init() async {
    _prefs = await (_initFuture ??= SharedPreferences.getInstance());
  }

  /// Generic getter for boolean values
  Future<bool> _getBool(String key, bool defaultValue) async {
    await init();
    return _prefs.getBool(key) ?? defaultValue;
  }

  /// Generic setter for boolean values
  Future<void> _setBool(String key, bool value) async {
    await init();
    await _prefs.setBool(key, value);
  }

  /// Generic getter for string values
  Future<String?> _getString(String key) async {
    await init();
    return _prefs.getString(key);
  }

  /// Generic setter for string values
  Future<void> _setString(String key, String value) async {
    await init();
    await _prefs.setString(key, value);
  }

  // ============================================
  // THEME SETTINGS
  // ============================================

  Future<ThemeMode> getThemeMode() async {
    final value = await _getString('theme_mode');
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _setString('theme_mode', value);
  }

  Future<Color> getPrimaryColor() async {
    final value = await _getString('primary_color');
    if (value != null) {
      try {
        return Color(int.parse(value.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return const Color(0xFFC4944E);
  }

  Future<void> setPrimaryColor(Color color) async {
    await _setString(
      'primary_color',
      '#${color.toARGB32().toRadixString(16).substring(2)}',
    );
  }

  // ============================================
  // NOTIFICATION SETTINGS
  // ============================================

  Future<bool> getNotificationsEnabled() =>
      _getBool('notifications_enabled', true);
  Future<void> setNotificationsEnabled(bool enabled) =>
      _setBool('notifications_enabled', enabled);

  Future<bool> getNewArticleNotifications() =>
      _getBool('new_article_notifs', true);
  Future<void> setNewArticleNotifications(bool enabled) =>
      _setBool('new_article_notifs', enabled);

  Future<bool> getInAppNotificationsEnabled() =>
      _getBool('in_app_notifications_enabled', true);
  Future<void> setInAppNotificationsEnabled(bool enabled) =>
      _setBool('in_app_notifications_enabled', enabled);

  // ============================================
  // APP SETTINGS
  // ============================================

  Future<bool> getAutoRefresh() => _getBool('auto_refresh', true);
  Future<void> setAutoRefresh(bool enabled) =>
      _setBool('auto_refresh', enabled);

  Future<int> getRefreshInterval() async {
    final value = await _getString('refresh_interval');
    return int.tryParse(value ?? '30') ?? 30;
  }

  Future<void> setRefreshInterval(int minutes) =>
      _setString('refresh_interval', minutes.toString());

  Future<int> getMaxArticles() async {
    final value = await _getString('max_articles');
    return int.tryParse(value ?? '500') ?? 500;
  }

  Future<void> setMaxArticles(int count) =>
      _setString('max_articles', count.toString());

  Future<bool> getShowImages() => _getBool('show_images', true);
  Future<void> setShowImages(bool enabled) => _setBool('show_images', enabled);

  Future<bool> getDataSaverMode() => _getBool('data_saver_mode', false);
  Future<void> setDataSaverMode(bool enabled) =>
      _setBool('data_saver_mode', enabled);

  // ============================================
  // DESIGN v2 PREFERENCES
  // Added in the redesign pass.
  // ============================================

  /// First-launch onboarding gate.
  Future<bool> getHasCompletedOnboarding() =>
      _getBool('onboarding_complete', false);
  Future<void> setHasCompletedOnboarding(bool value) =>
      _setBool('onboarding_complete', value);

  /// Lifetime "Pro" purchase flag. No current feature gates on this —
  /// exists so future features can check it cheaply.
  Future<bool> getIsPro() => _getBool('is_pro', false);
  Future<void> setIsPro(bool value) => _setBool('is_pro', value);

  /// Subscribed RSS source IDs (subset of RssFeedService.predefinedSources).
  /// Default: all sources. The set of subscribed IDs is the source-of-truth
  /// for filter — every read/write passes through here.
  Future<Set<String>> getSubscribedSourceIds() async {
    await init();
    final stored = _prefs.getStringList('subscribed_source_ids');
    if (stored == null) {
      // First run: subscribe to all sources by default.
      final all = canonicalSourceIds();
      await setSubscribedSourceIds(all);
      return all;
    }
    // Defensive: drop IDs that don't exist in the canonical list anymore.
    final canonical = canonicalSourceIds();
    return stored.where(canonical.contains).toSet();
  }

  Future<void> setSubscribedSourceIds(Set<String> ids) async {
    await init();
    await _prefs.setStringList('subscribed_source_ids', ids.toList());
  }

  /// Feed view mode: 'stack' (one card at a time, swipe) or
  /// 'continuous' (vertical list, time-grouped).
  Future<String> getFeedViewMode() async {
    final value = await _getString('feed_view_mode');
    return value == 'continuous' ? 'continuous' : 'stack';
  }

  Future<void> setFeedViewMode(String mode) =>
      _setString('feed_view_mode', mode);

  /// Editorial edition counter — increments on each successful refresh.
  Future<int> getEditionNumber() async {
    final value = await _getString('edition_number');
    return int.tryParse(value ?? '1') ?? 1;
  }

  Future<void> setEditionNumber(int value) =>
      _setString('edition_number', value.toString());
  Future<int> bumpEditionNumber() async {
    final current = await getEditionNumber();
    final next = current + 1;
    await setEditionNumber(next);
    return next;
  }

  // Reading preferences (passed through to ReaderPreferences).
  Future<ReaderTheme> getReaderTheme() async {
    final value = await _getString('reader_theme');
    return ReaderTheme.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ReaderTheme.defaultTheme,
    );
  }

  Future<void> setReaderTheme(ReaderTheme value) =>
      _setString('reader_theme', value.name);

  Future<double> getReaderFontSize() async {
    final value = await _getString('reader_font_size');
    return double.tryParse(value ?? '16') ?? 16;
  }

  Future<void> setReaderFontSize(double value) =>
      _setString('reader_font_size', value.toString());

  Future<double> getReaderLineHeight() async {
    final value = await _getString('reader_line_height');
    return double.tryParse(value ?? '1.6') ?? 1.6;
  }

  Future<void> setReaderLineHeight(double value) =>
      _setString('reader_line_height', value.toString());

  Future<bool> getMonoDatelinesEnabled() => _getBool('mono_datelines', true);
  Future<void> setMonoDatelinesEnabled(bool value) =>
      _setBool('mono_datelines', value);

  Future<bool> getWidenMeasure() => _getBool('widen_measure', false);
  Future<void> setWidenMeasure(bool value) => _setBool('widen_measure', value);

  /// Body font choice — applies to the in-app article reader only.
  /// `dm` (default) or `lora`.
  Future<String> getBodyFont() async {
    final v = await _getString('body_font');
    return (v == 'lora') ? 'lora' : 'dm';
  }

  Future<void> setBodyFont(String value) =>
      _setString('body_font', value == 'lora' ? 'lora' : 'dm');

  Future<ReadingPreferences> getReadingPreferences() async {
    return ReadingPreferences(
      theme: await getReaderTheme(),
      fontSize: await getReaderFontSize(),
      lineHeight: await getReaderLineHeight(),
      monoDatelines: await getMonoDatelinesEnabled(),
      widenMeasure: await getWidenMeasure(),
      bodyFont: await getBodyFont(),
    );
  }

  Future<ReaderTheme> getReaderThemeOrDefault() async => getReaderTheme();

  // ============================================
  // DEFAULT SETTINGS
  // ============================================

  Future<void> initializeDefaults() async {
    await init();

    if (_prefs.getString('theme_mode') == null) {
      await setThemeMode(ThemeMode.system);
    }
    if (!_prefs.containsKey('notifications_enabled')) {
      await setNotificationsEnabled(true);
    }
    if (!_prefs.containsKey('new_article_notifs')) {
      await setNewArticleNotifications(true);
    }
    if (!_prefs.containsKey('in_app_notifications_enabled')) {
      await setInAppNotificationsEnabled(true);
    }
    if (!_prefs.containsKey('auto_refresh')) {
      await setAutoRefresh(true);
    }
    if (_prefs.getString('refresh_interval') == null) {
      await setRefreshInterval(30);
    }
    if (_prefs.getString('max_articles') == null) {
      await setMaxArticles(500);
    }
    if (!_prefs.containsKey('show_images')) {
      await setShowImages(true);
    }
  }
}
