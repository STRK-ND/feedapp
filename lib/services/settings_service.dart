import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rss_source.dart';
import '../utils/constants.dart';
import '../utils/reader_theme.dart';
import 'rss_feed_service.dart';
import 'sync_hooks.dart';

/// App Settings Service - manages all app preferences using SharedPreferences
class SettingsService {
  late SharedPreferences _prefs;
  Future<SharedPreferences>? _initFuture;

  /// Cloud-sync push hook. Assigned by the service locator after the sync
  /// service exists (avoids get-it circular construction). Null in tests
  /// and when signed out.
  SyncHooks? syncHooks;

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
    syncHooks?.onSettingsChanged();
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
    syncHooks?.onSettingsChanged();
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

  /// Which article categories trigger "new articles" pushes. Stored as []
  /// (= unrestricted / all); reads always normalize back to the full list
  /// so callers never see an empty restriction. Sent to the worker inside
  /// the /subscribe preferences object; the server filters announcements
  /// per token.
  static const String _kNotificationCategoriesKey = 'notification_categories';

  Future<List<String>> getNotificationCategories() async {
    await init();
    final stored = _prefs.getStringList(_kNotificationCategoriesKey);
    if (stored == null || stored.isEmpty) {
      return List.of(AppConfig.categories)..remove('All');
    }
    return stored;
  }

  Future<void> setNotificationCategories(List<String> categories) async {
    await init();
    final valid = AppConfig.categories.where(categories.contains).toList();
    final all =
        valid.length == AppConfig.categories.length - 1 || valid.isEmpty;
    await _prefs.setStringList(
      _kNotificationCategoriesKey,
      all ? <String>[] : valid, // [] = unrestricted
    );
    syncHooks?.onSourcesChanged();
  }

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

  /// Subscribed RSS source IDs. Includes canonical ids plus any user-added
  /// custom feed ids. Default: all canonical sources. The set of subscribed
  /// IDs is the source-of-truth for filter — every read/write passes here.
  Future<Set<String>> getSubscribedSourceIds() async {
    await init();
    final stored = _prefs.getStringList('subscribed_source_ids');
    if (stored == null) {
      // First run: subscribe to all sources by default.
      final all = canonicalSourceIds();
      await setSubscribedSourceIds(all);
      return all;
    }
    // Defensive: drop ids that no longer resolve to a known source
    // (canonical list or a persisted custom source).
    final canonical = canonicalSourceIds();
    final customIds = (await getCustomSources()).map((s) => s.id).toSet();
    return stored
        .where((id) => canonical.contains(id) || customIds.contains(id))
        .toSet();
  }

  Future<void> setSubscribedSourceIds(Set<String> ids) async {
    await init();
    await _prefs.setStringList('subscribed_source_ids', ids.toList());
    syncHooks?.onSourcesChanged();
  }

  /// User-added custom feeds (arbitrary RSS/Atom URLs fetched client-side).
  /// Stored as JSON blobs; these are the only non-canonical source ids
  /// [getSubscribedSourceIds] will keep.
  static const String _kCustomSourcesKey = 'custom_sources';

  Future<List<RssSource>> getCustomSources() async {
    await init();
    final stored = _prefs.getStringList(_kCustomSourcesKey);
    if (stored == null || stored.isEmpty) return [];
    final sources = <RssSource>[];
    for (final raw in stored) {
      try {
        sources.add(
          RssSource.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip corrupt records instead of losing the whole list.
      }
    }
    return sources;
  }

  Future<void> setCustomSources(List<RssSource> sources) async {
    await init();
    await _prefs.setStringList(
      _kCustomSourcesKey,
      sources.map((s) => jsonEncode(s.toJson())).toList(),
    );
    syncHooks?.onSourcesChanged();
  }

  /// Adds a custom source if its URL is new; returns the full updated list.
  Future<List<RssSource>> addCustomSource(String name, String url) async {
    final current = await getCustomSources();
    final normalized = url.trim();
    if (current.any(
      (s) => s.url.trim().toLowerCase() == normalized.toLowerCase(),
    )) {
      return current;
    }
    final source = RssSource.custom(
      id: RssSource.stableIdForUrl(normalized),
      name: name.trim().isEmpty ? Uri.parse(normalized).host : name.trim(),
      url: normalized,
    );
    final next = [...current, source];
    await setCustomSources(next);
    return next;
  }

  /// Removes the custom source with [id] and unsubscribes it.
  Future<void> removeCustomSource(String id) async {
    final current = await getCustomSources();
    final next = current.where((s) => s.id != id).toList();
    await setCustomSources(next);
    final subs = await getSubscribedSourceIds();
    subs.remove(id);
    await setSubscribedSourceIds(subs);
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
  // CLOUD SYNC (account backup / restore)
  // ============================================

  /// Preference keys mirrored to the user's cloud account. Device-local
  /// state (onboarding gate, edition counter) is intentionally excluded.
  static const List<String> _syncedStringKeys = [
    'theme_mode',
    'primary_color',
    'refresh_interval',
    'max_articles',
    'feed_view_mode',
    'reader_theme',
    'reader_font_size',
    'reader_line_height',
    'body_font',
  ];
  static const List<String> _syncedBoolKeys = [
    'notifications_enabled',
    'new_article_notifs',
    'in_app_notifications_enabled',
    'auto_refresh',
    'show_images',
    'data_saver_mode',
    'is_pro',
    'mono_datelines',
    'widen_measure',
  ];
  static const List<String> _syncedListKeys = [
    'notification_categories',
    'subscribed_source_ids',
    'custom_sources',
  ];

  /// Current values of all synced keys (absent keys are omitted).
  Future<Map<String, Object?>> snapshotForSync() async {
    await init();
    final out = <String, Object?>{};
    for (final k in _syncedStringKeys) {
      final v = _prefs.getString(k);
      if (v != null) out[k] = v;
    }
    for (final k in _syncedBoolKeys) {
      final v = _prefs.getBool(k);
      if (v != null) out[k] = v;
    }
    for (final k in _syncedListKeys) {
      final v = _prefs.getStringList(k);
      if (v != null) out[k] = v;
    }
    return out;
  }

  /// Apply a cloud snapshot with raw writes — restoring must not echo back
  /// through the push hooks. Values are type-checked per key list.
  Future<void> restoreFromSync(Map<String, Object?> values) async {
    await init();
    for (final k in _syncedStringKeys) {
      final v = values[k];
      if (v is String) await _prefs.setString(k, v);
    }
    for (final k in _syncedBoolKeys) {
      final v = values[k];
      if (v is bool) await _prefs.setBool(k, v);
    }
    for (final k in _syncedListKeys) {
      final v = values[k];
      if (v is List) await _prefs.setStringList(k, v.cast<String>());
    }
  }

  // Last-sync clocks for the two snapshot docs. Raw writes: these are sync
  // bookkeeping and must never trigger a push themselves.
  static const String _kSettingsSyncTsKey = 'sync_settings_updated_at';
  static const String _kSourcesSyncTsKey = 'sync_sources_updated_at';

  Future<int> getSettingsSyncTs() async {
    await init();
    return _prefs.getInt(_kSettingsSyncTsKey) ?? 0;
  }

  Future<void> setSettingsSyncTs(int ts) async {
    await init();
    await _prefs.setInt(_kSettingsSyncTsKey, ts);
  }

  Future<int> getSourcesSyncTs() async {
    await init();
    return _prefs.getInt(_kSourcesSyncTsKey) ?? 0;
  }

  Future<void> setSourcesSyncTs(int ts) async {
    await init();
    await _prefs.setInt(_kSourcesSyncTsKey, ts);
  }

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
