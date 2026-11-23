import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'design_tokens.dart';

/// App configuration constants.
///
/// Colours, spacing, radius, motion and type all live in
/// `design_tokens.dart`; per-category accents live in `category_accent.dart`.
/// This file holds only values that are configuration, not design.
class AppConfig {
  AppConfig._();

  // App info
  static const String appName = 'Curated Feeds';
  static String? _cachedVersion;

  /// App version — loaded from PackageInfo, falls back to '0.0.0'
  static Future<String> getVersion() async {
    _cachedVersion ??= (await PackageInfo.fromPlatform()).version;
    return _cachedVersion!;
  }

  // Worker API settings
  static String get workerApiUrl => const String.fromEnvironment(
    'WORKER_API_URL',
    defaultValue: 'https://curated-feeds-worker.raj15400881.workers.dev/',
  );
  static const int workerTimeoutSeconds = 8;

  /// Shared secret header sent to the worker on app-side API calls.
  /// Empty when not compiled in via --dart-define=WORKER_API_SECRET=...
  static const String workerApiSecret = String.fromEnvironment(
    'WORKER_API_SECRET',
    defaultValue: '',
  );

  /// Support email — shown in Settings and used for the mailto link.
  static const String supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'rajatkashyap7062@gmail.com',
  );

  static const int rssTimeoutSeconds = 8;
  static const int maxArticlesPerSource = 20;

  /// Pro monetization caps. The Play Store build ships a smaller free cap
  /// (store listing discloses it); the sideload/GitHub build keeps the
  /// original generous cap.
  static int get freeSavedArticlesCap => isPlayStoreBuild ? 5 : 25;

  /// True when compiled with --dart-define=PLAY_STORE_BUILD=true.
  ///
  /// The Play Store forbids self-updating package installs, so Play builds
  /// disable the entire GitHub-Releases OTA path (checkForUpdates and
  /// everything downstream: dialog, notification, download, installer) and
  /// ship the REQUEST_INSTALL_PACKAGES permission removal via the `play`
  /// flavor manifest. Updates on Play come exclusively from the store.
  static const bool isPlayStoreBuild = bool.fromEnvironment(
    'PLAY_STORE_BUILD',
    defaultValue: false,
  );

  static const int maxCachedArticles = 1000;

  /// XML parsing limits (for security)
  static const int maxXmlSizeBytes = 5 * 1024 * 1024; // 5MB

  static const int maxApkDownloadSizeMB = 100;

  /// Category list, 'All' first. Category accents live in [CategoryAccent].
  static const List<String> categories = [
    'All',
    'Tech',
    'News',
    'Sports',
    'Entertainment',
    'Gaming',
  ];
}

/// Get article image hero tag for shared element transitions
String getArticleHeroTag(String articleId) => 'article-hero-$articleId';

/// Card decorations shared by several surfaces.
///
/// Radii come from [AppRadius] and durations from [AppMotion]; this class
/// only composes them into whole decorations.
class AppCardStyles {
  AppCardStyles._();

  /// Category chip glass effect
  static BoxDecoration chipDecoration(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.chip),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
    );
  }
}

/// Design tokens for the premium curved bottom navigation bar
class CurvedNavTokens {
  CurvedNavTokens._();

  // Dimensions
  static const double barHeight = 64.0;
  static const double barRadius = 0.0;
  static const double barBottomMargin = 0.0;
  static const double barHorizontalPadding = 0.0;
  static const double itemPadding = 16.0;
  static const double iconSize = 24.0;
  static const double iconScaleSelected = 1.15;
  static const double labelFontSize = 11.0;
  static const double indicatorTopInset = 6.0;
  static const double indicatorDotRadius = 1.75;

  // Light mode
  static const Color lightBarFill = Color(0xFFFFFFFF);

  // Animations
  static const Duration slideDuration = Duration(milliseconds: 300);
  static const Duration iconDuration = Duration(milliseconds: 250);
  static const Duration labelDuration = Duration(milliseconds: 300);
  static const Curve slideCurve = Curves.easeOutCubic;
  static const Curve iconCurve = Curves.easeOutBack;
  static const Curve labelCurve = Curves.easeOutCubic;
}
