import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode storage keys
class ThemeKeys {
  static const String themeMode = 'theme_mode';
  static const String primaryColor = 'primary_color';
}

/// Notification settings keys
class NotificationKeys {
  static const String notificationsEnabled = 'notifications_enabled';
  static const String newArticleNotifs = 'new_article_notifs';
  static const String savedArticleNotifs = 'saved_article_notifs';
  static const String inAppNotificationsEnabled =
      'in_app_notifications_enabled';
}

/// App settings keys
class AppSettingsKeys {
  static const String autoRefresh = 'auto_refresh';
  static const String refreshInterval = 'refresh_interval';
  static const String maxArticles = 'max_articles';
  static const String offlineMode = 'offline_mode';
  static const String showImages = 'show_images';
  static const String dataSaverMode = 'data_saver_mode';
}

/// App Settings Service - manages all app preferences using SharedPreferences
class SettingsService {
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  /// Initialize SharedPreferences
  Future<void> init() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  // ============================================
  // THEME SETTINGS
  // ============================================

  /// Get current theme mode
  Future<ThemeMode> getThemeMode() async {
    await init();
    final value = _prefs.getString(ThemeKeys.themeMode);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    await init();
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    await _prefs.setString(ThemeKeys.themeMode, value);
  }

  /// Get primary color
  Future<Color> getPrimaryColor() async {
    await init();
    final value = _prefs.getString(ThemeKeys.primaryColor);
    if (value != null) {
      try {
        return Color(int.parse(value.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return const Color(0xFF1A1B4D);
  }

  /// Set primary color
  Future<void> setPrimaryColor(Color color) async {
    await init();
    await _prefs.setString(
      ThemeKeys.primaryColor,
      '#${color.toARGB32().toRadixString(16).substring(2)}',
    );
  }

  // ============================================
  // NOTIFICATION SETTINGS
  // ============================================

  /// Get notifications enabled status
  Future<bool> getNotificationsEnabled() async {
    await init();
    return _prefs.getString(NotificationKeys.notificationsEnabled) == 'true';
  }

  /// Set notifications enabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    await init();
    await _prefs.setString(
      NotificationKeys.notificationsEnabled,
      enabled.toString(),
    );
  }

  /// Get new article notifications
  Future<bool> getNewArticleNotifications() async {
    await init();
    return _prefs.getString(NotificationKeys.newArticleNotifs) == 'true';
  }

  /// Set new article notifications
  Future<void> setNewArticleNotifications(bool enabled) async {
    await init();
    await _prefs.setString(
      NotificationKeys.newArticleNotifs,
      enabled.toString(),
    );
  }

  /// Get saved article notifications
  Future<bool> getSavedArticleNotifications() async {
    await init();
    return _prefs.getString(NotificationKeys.savedArticleNotifs) == 'true';
  }

  /// Set saved article notifications
  Future<void> setSavedArticleNotifications(bool enabled) async {
    await init();
    await _prefs.setString(
      NotificationKeys.savedArticleNotifs,
      enabled.toString(),
    );
  }

  /// Get in-app notifications enabled
  Future<bool> getInAppNotificationsEnabled() async {
    await init();
    return _prefs.getString(NotificationKeys.inAppNotificationsEnabled) !=
        'false';
  }

  /// Set in-app notifications enabled
  Future<void> setInAppNotificationsEnabled(bool enabled) async {
    await init();
    await _prefs.setString(
      NotificationKeys.inAppNotificationsEnabled,
      enabled.toString(),
    );
  }

  // ============================================
  // APP SETTINGS
  // ============================================

  /// Get auto refresh enabled
  Future<bool> getAutoRefresh() async {
    await init();
    final value = _prefs.getString(AppSettingsKeys.autoRefresh);
    return value != 'false';
  }

  /// Set auto refresh
  Future<void> setAutoRefresh(bool enabled) async {
    await init();
    await _prefs.setString(AppSettingsKeys.autoRefresh, enabled.toString());
  }

  /// Get refresh interval in minutes
  Future<int> getRefreshInterval() async {
    await init();
    final value = _prefs.getString(AppSettingsKeys.refreshInterval);
    return int.tryParse(value ?? '30') ?? 30;
  }

  /// Set refresh interval
  Future<void> setRefreshInterval(int minutes) async {
    await init();
    await _prefs.setString(AppSettingsKeys.refreshInterval, minutes.toString());
  }

  /// Get max articles to cache
  Future<int> getMaxArticles() async {
    await init();
    final value = _prefs.getString(AppSettingsKeys.maxArticles);
    return int.tryParse(value ?? '500') ?? 500;
  }

  /// Set max articles
  Future<void> setMaxArticles(int count) async {
    await init();
    await _prefs.setString(AppSettingsKeys.maxArticles, count.toString());
  }

  /// Get offline mode preference
  Future<bool> getOfflineMode() async {
    await init();
    return _prefs.getString(AppSettingsKeys.offlineMode) == 'true';
  }

  /// Set offline mode
  Future<void> setOfflineMode(bool enabled) async {
    await init();
    await _prefs.setString(AppSettingsKeys.offlineMode, enabled.toString());
  }

  /// Get show images preference
  Future<bool> getShowImages() async {
    await init();
    return _prefs.getString(AppSettingsKeys.showImages) != 'false';
  }

  /// Set show images
  Future<void> setShowImages(bool enabled) async {
    await init();
    await _prefs.setString(AppSettingsKeys.showImages, enabled.toString());
  }

  /// Get data saver mode
  Future<bool> getDataSaverMode() async {
    await init();
    return _prefs.getString(AppSettingsKeys.dataSaverMode) == 'true';
  }

  /// Set data saver mode
  Future<void> setDataSaverMode(bool enabled) async {
    await init();
    await _prefs.setString(AppSettingsKeys.dataSaverMode, enabled.toString());
  }

  // ============================================
  // DEFAULT SETTINGS
  // ============================================

  /// Initialize default settings
  Future<void> initializeDefaults() async {
    await init();

    if (_prefs.getString(ThemeKeys.themeMode) == null) {
      await setThemeMode(ThemeMode.system);
    }
    if (_prefs.getString(NotificationKeys.notificationsEnabled) == null) {
      await setNotificationsEnabled(true);
    }
    if (_prefs.getString(NotificationKeys.newArticleNotifs) == null) {
      await setNewArticleNotifications(true);
    }
    if (_prefs.getString(NotificationKeys.inAppNotificationsEnabled) == null) {
      await setInAppNotificationsEnabled(true);
    }
    if (_prefs.getString(AppSettingsKeys.autoRefresh) == null) {
      await setAutoRefresh(true);
    }
    if (_prefs.getString(AppSettingsKeys.refreshInterval) == null) {
      await setRefreshInterval(30);
    }
    if (_prefs.getString(AppSettingsKeys.maxArticles) == null) {
      await setMaxArticles(500);
    }
    if (_prefs.getString(AppSettingsKeys.showImages) == null) {
      await setShowImages(true);
    }
  }
}
