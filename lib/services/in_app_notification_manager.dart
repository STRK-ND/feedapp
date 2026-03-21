import 'dart:async';
import 'package:flutter/material.dart';
import '../models/in_app_notification.dart';

/// Manager for displaying in-app notifications as overlays
class InAppNotificationManager extends ChangeNotifier {
  static final InAppNotificationManager _instance = InAppNotificationManager._internal();
  factory InAppNotificationManager() => _instance;
  InAppNotificationManager._internal();

  final List<InAppNotification> _notifications = [];
  final StreamController<InAppNotification> _notificationStreamController =
      StreamController<InAppNotification>.broadcast();

  bool _isEnabled = true;
  Duration _displayDuration = const Duration(seconds: 4);

  List<InAppNotification> get notifications => List.unmodifiable(_notifications);
  Stream<InAppNotification> get notificationStream => _notificationStreamController.stream;
  bool get isEnabled => _isEnabled;
  Duration get displayDuration => _displayDuration;

  /// Enable or disable in-app notifications
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  /// Set display duration for notifications
  void setDisplayDuration(Duration duration) {
    _displayDuration = duration;
    notifyListeners();
  }

  /// Show a notification
  void showNotification(InAppNotification notification) {
    if (!_isEnabled) return;

    _notifications.add(notification);
    _notificationStreamController.add(notification);
    notifyListeners();

    // Auto-dismiss after duration
    Timer(_displayDuration, () {
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
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Dismiss all notifications
  void dismissAll() {
    _notifications.clear();
    notifyListeners();
  }

  /// Clear notifications stream on dispose
  void disposeManager() {
    _notificationStreamController.close();
  }
}
