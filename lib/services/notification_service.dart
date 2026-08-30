import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'in_app_notification_manager.dart';
import '../models/in_app_notification.dart';
import '../di/service_locator.dart';
import '../utils/constants.dart';
import 'settings_service.dart';
import 'update_service.dart';

/// Service for handling push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  // ---------------------------------------------------------------------------
  // Server-side push subscription (worker at AppConfig.workerApiUrl).
  // Static so unit tests don't need to construct NotificationService (which
  // eagerly boots Firebase). The FCM token is passed in explicitly, the
  // http.Client is injectable, and SettingsService supplies prefs.
  // ---------------------------------------------------------------------------

  /// Base headers for worker calls. Sends the shared API secret when
  /// one was compiled in via --dart-define=WORKER_API_SECRET.
  static Map<String, String> _workerHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (AppConfig.workerApiSecret.isNotEmpty) {
      headers['x-api-secret'] = AppConfig.workerApiSecret;
    }
    return headers;
  }

  /// Re-register the FCM token with the worker. Call this on app start
  /// when notifications are enabled, and from the Settings toggle
  /// handler. ponytail: skip onTokenRefresh listener — re-POST on
  /// initialize() covers rotation idempotently; add when a stale-token
  /// report actually lands.
  static Future<void> enablePushNotifications({
    String? fcmToken,
    http.Client? httpClient,
  }) async {
    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    try {
      final token = fcmToken ?? NotificationService()._fcmToken;
      if (token == null) {
        throw StateError('No FCM token available');
      }

      final settingsService = getIt<SettingsService>();
      final newArticlesEnabled = await settingsService
          .getNewArticleNotifications();
      // [] = unrestricted (all categories) — the worker narrows per token.
      final categories = await settingsService.getNotificationCategories();

      final uri = Uri.parse('${AppConfig.workerApiUrl}subscribe');
      final headers = _workerHeaders();
      final response = await client
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'token': token,
              'topic': 'new-articles',
              'preferences': {
                'newArticles': newArticlesEnabled,
                if (categories.length < AppConfig.categories.length - 1)
                  'categories': categories,
              },
            }),
          )
          .timeout(const Duration(seconds: AppConfig.workerTimeoutSeconds));

      if (response.statusCode != 200) {
        throw StateError(
          'Push subscription failed: HTTP ${response.statusCode}',
        );
      }
    } finally {
      // Per-call client: close it (and its connection pool) unless a test
      // injected its own, which the caller owns (data-layer L7).
      if (ownsClient) client.close();
    }
  }

  /// Remove the FCM token from the worker's subscription store.
  static Future<void> disablePushNotifications({
    String? fcmToken,
    http.Client? httpClient,
  }) async {
    final ownsClient = httpClient == null;
    final client = httpClient ?? http.Client();
    try {
      final token = fcmToken ?? NotificationService()._fcmToken;
      if (token == null) return; // nothing to disable

      final uri = Uri.parse('${AppConfig.workerApiUrl}subscribe');
      await client
          .delete(
            uri,
            headers: _workerHeaders(),
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: AppConfig.workerTimeoutSeconds));
    } finally {
      if (ownsClient) client.close();
    }
  }

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check if notifications are enabled
    final settingsService = getIt<SettingsService>();
    final notificationsEnabled = await settingsService
        .getNotificationsEnabled();

    // Always obtain the FCM token — it's a device registration, not a
    // permission. Skipping it when push was off at launch left _fcmToken
    // null for the whole process, so toggling push ON later threw
    // "No FCM token available" with no path to recover (data-layer H2).
    try {
      _fcmToken ??= await _firebaseMessaging.getToken();
      if (_fcmToken != null && kDebugMode) {
        // Never in release logs — logcat is world-readable over adb.
        debugPrint(
          '[Notification] FCM Token: ${_fcmToken!.substring(0, 20)}...',
        );
      }
    } catch (e) {
      debugPrint('[Notification] Failed to obtain FCM token: $e');
    }

    if (!notificationsEnabled) {
      debugPrint(
        '[Notification] Notifications disabled by user, skipping init',
      );
      _isInitialized = true;
      return;
    }

    // Request permissions (iOS)
    await _requestPermissions();

    // Initialize local notifications
    await _initLocalNotifications();

    // Re-register with the worker — upsert is idempotent on the server
    // and covers token rotation, stale data, and uninstall-reinstall.
    unawaited(
      NotificationService.enablePushNotifications().catchError((Object e) {
        debugPrint('[Notification] Failed to register token with worker: $e');
      }),
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

    // Handle notification tap when app is in terminated state
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    _isInitialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    // iOS permissions
    final iosSettings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
      '[Notification] iOS Permission status: ${iosSettings.authorizationStatus}',
    );

    // Android 13+ permissions
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Initialize local notifications
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  /// Handle notification tap
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      debugPrint('[Notification] Tapped with payload: $payload');
      _handleUpdateNotificationTap(payload);
    }
  }

  /// Foreground/background scheduled local notification (the OTA
  /// announcement). Stored in [SharedPreferences] so that cold-start
  /// launches where the app was opened *by* the tap can find it.
  static const String _pendingUpdatePayloadKey = 'pending_update_payload';

  /// Schedule a high-priority heads-up local notification announcing
  /// that a new release is available, with the `UpdateInfo` payload
  /// for tap-to-update routing. Suppresses re-announcing the same
  /// version on subsequent cold starts, so the user is notified once
  /// per published release.
  Future<void> announceUpdate(UpdateInfo info) async {
    final settingsService = getIt<SettingsService>();
    if (!await settingsService.getNotificationsEnabled()) {
      debugPrint(
        '[Notification] announceUpdate: notifications disabled by user, skipping',
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastAnnounced = prefs.getString('last_announced_update_version');
    if (lastAnnounced == info.version) {
      debugPrint(
        '[Notification] announceUpdate: version ${info.version} already announced, skipping',
      );
      return;
    }

    const channelId = 'ota_updates';
    const channelName = 'Curated Feeds updates';
    const channelDescription =
        'Heads-up announcement when a new app version is published.';

    final android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: '${info.version} is available',
      styleInformation: BigTextStyleInformation(
        info.releaseNotes.isEmpty
            ? 'Version ${info.version} is available.'
            : info.releaseNotes,
      ),
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    final details = NotificationDetails(android: android, iOS: ios);

    final payload = jsonEncode({
      'type': 'ota_update',
      'version': info.version,
      'downloadUrl': info.downloadUrl,
      'releaseNotes': info.releaseNotes,
      'htmlUrl': info.htmlUrl,
      'releaseDate': info.releaseDate,
    });

    // Strip the first line of release notes as the visible body —
    // BigTextStyle expands when the user long-presses the notification.
    final firstLine = info.releaseNotes.isEmpty
        ? 'Tap to update Curated Feeds.'
        : (info.releaseNotes.split('\n').first.length > 80
              ? '${info.releaseNotes.substring(0, 77)}…'
              : info.releaseNotes.split('\n').first);

    await _localNotifications.show(
      id: _kOtaNotificationId,
      title: 'Version ${info.version} is available',
      body: firstLine,
      notificationDetails: details,
      payload: payload,
    );

    await prefs.setString(_pendingUpdatePayloadKey, payload);
    await prefs.setString('last_announced_update_version', info.version);

    debugPrint('[Notification] Scheduled OTA announcement for ${info.version}');
  }

  /// Stable ID used for the OTA announcement notification. Re-using
  /// the same id means a newer version supersedes the older one
  /// instead of stacking two banners.
  static const int _kOtaNotificationId = 8001;

  /// Consumer tap-handler. Set via [setUpdateNotificationTapHandler]
  /// from a UI entry-point that has access to a `BuildContext`. The
  /// default implementation just logs the payload — the host app
  /// overrides this with the actual "start the install" flow.
  void Function(String payload)? _updateTapHandler;
  void setUpdateNotificationTapHandler(void Function(String payload)? h) {
    _updateTapHandler = h;
  }

  /// Tap-handler for "new articles" FCM pushes. The UI layer registers
  /// a callback that navigates to the feed tab; without it, tapping the
  /// push only logs (the previous behavior).
  void Function(Map<String, dynamic> data)? _newArticleTapHandler;
  void setNewArticleTapHandler(void Function(Map<String, dynamic> data)? h) {
    _newArticleTapHandler = h;
  }

  /// Called from cold-start / background-tap callback when the local
  /// notification plugin hand the tap to us. Pulls the cached JSON
  /// out of SharedPreferences so a cold-start launch (the plugin
  /// may have already cleared its in-memory tap queue) still has
  /// the UpdateInfo available.
  ///
  /// Two entry points:
  /// - [calledWith] != null: a tap callback handed us a payload
  ///   string. Parse it, but ALSO read+clear the cached version
  ///   (prewarm).
  /// - [calledWith] == null: cold-start check. Read-and-clear
  ///   the cached payload; returns null if there was nothing.
  Future<UpdateInfo?> consumeUpdateNotificationPayload(
    String? calledWith,
  ) async {
    String? payload = calledWith;
    final prefs = await SharedPreferences.getInstance();
    // Always drain the cached copy. A warm tap (calledWith != null) must
    // also clear it — otherwise the same payload re-fires the auto-update
    // flow on the next cold start (data-layer M4).
    final cached = prefs.getString(_pendingUpdatePayloadKey);
    if (cached != null) {
      await prefs.remove(_pendingUpdatePayloadKey);
      payload ??= cached;
    }
    if (payload == null) return null;
    return _decodePayload(payload);
  }

  /// Parse the JSON payload back to [UpdateInfo]. Public so the
  /// cold-start path can call it directly without round-tripping
  /// through SharedPreferences when the payload is already in hand.
  Future<UpdateInfo?> parseUpdatePayload(String payload) async {
    return _decodePayload(payload);
  }

  Future<UpdateInfo?> _decodePayload(String payload) async {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] != 'ota_update') return null;
      return UpdateInfo(
        version: data['version'] as String? ?? '',
        downloadUrl: data['downloadUrl'] as String? ?? '',
        releaseNotes: data['releaseNotes'] as String? ?? '',
        htmlUrl: data['htmlUrl'] as String? ?? '',
        releaseDate: data['releaseDate'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[Notification] Failed to parse update payload: $e');
      return null;
    }
  }

  void _handleUpdateNotificationTap(String payload) {
    if (_updateTapHandler != null) {
      _updateTapHandler!(payload);
    } else {
      debugPrint(
        '[Notification] no tap handler registered — payload saved for cold start',
      );
    }
  }

  /// Handle foreground message
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint(
      '[Notification] Foreground message: ${message.notification?.title}',
    );

    // Check if in-app notifications are enabled
    final settingsService = getIt<SettingsService>();
    final inAppEnabled = await settingsService.getInAppNotificationsEnabled();
    if (!inAppEnabled) return;

    final title = message.notification?.title ?? 'New Article';
    final body = message.notification?.body ?? 'Check out the latest articles!';

    _showInAppNotification(title: title, body: body, data: message.data);
  }

  /// Handle background message (must be top-level function)
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint(
      '[Notification] Background message: ${message.notification?.title}',
    );
  }

  /// Handle notification tap from terminated/background
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[Notification] Tapped from: ${message.from}');

    // Route "new articles" pushes into the app: the registered handler
    // (MainNavigation) switches to the feed tab. Data-only or notification
    // messages without our type marker still route — any tap on a push we
    // sent means "show me what's new".
    final data = <String, dynamic>{...message.data};
    if (message.notification?.title != null) {
      data['title'] ??= message.notification!.title;
    }
    _newArticleTapHandler?.call(data);
  }

  /// Show in-app notification banner
  void _showInAppNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    // Read notification type from message data map
    final typeValue = data?['type'] ?? data?['notification_type'];
    final notificationType =
        typeValue == 'breaking' || typeValue == 'breakingNews'
        ? NotificationType.breakingNews
        : NotificationType.newArticle;

    InAppNotificationManager().showFirebaseNotification(
      title: title,
      body: body,
      payload: data?.toString(),
      type: notificationType,
    );
  }

  /// Get FCM token
  String? get fcmToken => _fcmToken;
}
