import 'package:flutter/material.dart';

/// Model for in-app notifications
class InAppNotification {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final String? payload;
  final DateTime timestamp;
  final NotificationType type;
  final VoidCallback? onTap;

  InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.payload,
    required this.timestamp,
    this.type = NotificationType.info,
    this.onTap,
  });

  factory InAppNotification.fromFirebaseMessage({
    required String title,
    required String body,
    String? imageUrl,
    String? payload,
    NotificationType type = NotificationType.info,
    VoidCallback? onTap,
  }) {
    return InAppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      imageUrl: imageUrl,
      payload: payload,
      timestamp: DateTime.now(),
      type: type,
      onTap: onTap,
    );
  }
}

/// Notification type for different visual styles
enum NotificationType {
  info,
  success,
  warning,
  error,
  newArticle,
  breakingNews,
}

extension NotificationTypeExtension on NotificationType {
  Color get backgroundColor {
    switch (this) {
      case NotificationType.info:
        return const Color(0xFF2196F3);
      case NotificationType.success:
        return const Color(0xFF4CAF50);
      case NotificationType.warning:
        return const Color(0xFFFF9800);
      case NotificationType.error:
        return const Color(0xFFF44336);
      case NotificationType.newArticle:
        return const Color(0xFF9C27B0);
      case NotificationType.breakingNews:
        return const Color(0xFFE53935);
    }
  }

  Color get iconColor {
    switch (this) {
      case NotificationType.info:
        return const Color(0xFF1976D2);
      case NotificationType.success:
        return const Color(0xFF388E3C);
      case NotificationType.warning:
        return const Color(0xFFF57C00);
      case NotificationType.error:
        return const Color(0xFFD32F2F);
      case NotificationType.newArticle:
        return const Color(0xFF7B1FA2);
      case NotificationType.breakingNews:
        return const Color(0xFFC62828);
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationType.info:
        return Icons.info_outline;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.newArticle:
        return Icons.article_outlined;
      case NotificationType.breakingNews:
        return Icons.campaign_outlined;
    }
  }
}
