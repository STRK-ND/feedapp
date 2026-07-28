import 'dart:async';
import 'package:flutter/material.dart';
import '../models/in_app_notification.dart';

/// Manager for displaying in-app notifications as overlays
class InAppNotificationManager extends ChangeNotifier {
  static final InAppNotificationManager _instance = InAppNotificationManager._internal();
  factory InAppNotificationManager() => _instance;
  InAppNotificationManager._internal();

  final List<InAppNotification> _notifications = [];
  StreamController<InAppNotification>? _notificationStreamController;
  final Map<String, Timer> _dismissTimers = {};

  bool _isEnabled = true;
  static const Duration displayDuration = Duration(seconds: 4);

  List<InAppNotification> get notifications => List.unmodifiable(_notifications);
  Stream<InAppNotification> get notificationStream {
    _notificationStreamController ??= StreamController<InAppNotification>.broadcast();
    return _notificationStreamController!.stream;
  }
  bool get isEnabled => _isEnabled;

  /// Enable or disable in-app notifications
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  /// Ensure stream controller is available
  void _ensureStreamController() {
    if (_notificationStreamController == null || _notificationStreamController!.isClosed) {
      _notificationStreamController = StreamController<InAppNotification>.broadcast();
    }
  }

  /// Show a notification
  void showNotification(InAppNotification notification) {
    if (!_isEnabled) return;

    _ensureStreamController();

    // Cancel any existing timer for this notification id
    _dismissTimers[notification.id]?.cancel();

    _notifications.add(notification);
    _notificationStreamController?.add(notification);
    notifyListeners();

    // Auto-dismiss after duration - track the timer
    _dismissTimers[notification.id] = Timer(displayDuration, () {
      _dismissTimers.remove(notification.id);
      dismissNotification(notification.id);
    });
  }

  /// Show notification from Firebase message
  void showFirebaseNotification({
    required String title,
    required String body,
    String? imageUrl,
    String? payload,
    NotificationType type = NotificationType.newArticle,
    VoidCallback? onTap,
  }) {
    final notification = InAppNotification.fromFirebaseMessage(
      title: title,
      body: body,
      imageUrl: imageUrl,
      payload: payload,
      type: type,
      onTap: onTap,
    );
    showNotification(notification);
  }

  /// Dismiss a specific notification
  void dismissNotification(String id) {
    // Cancel the timer for this notification
    _dismissTimers[id]?.cancel();
    _dismissTimers.remove(id);

    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Dismiss all notifications
  void dismissAll() {
    // Cancel all timers
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();

    _notifications.clear();
    notifyListeners();
  }

  /// Clear notifications stream on dispose
  void disposeManager() {
    // Cancel all timers but don't close the stream controller
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    // Do NOT close _notificationStreamController to allow singleton reuse
  }
}
