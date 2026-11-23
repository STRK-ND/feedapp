import 'package:flutter/material.dart';
import '../utils/category_accent.dart';
import '../utils/design_tokens.dart';

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
    final now = DateTime.now();
    return InAppNotification(
      id: '${now.microsecondsSinceEpoch}_${now.millisecondsSinceEpoch % 1000}',
      title: title,
      body: body,
      imageUrl: imageUrl,
      payload: payload,
      timestamp: now,
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
        return CategoryAccent.tech;
      case NotificationType.success:
        return CategoryAccent.sports;
      case NotificationType.warning:
        return AppColors.curation;
      case NotificationType.error:
        return CategoryAccent.news;
      case NotificationType.newArticle:
        return AppColors.curation;
      case NotificationType.breakingNews:
        return CategoryAccent.news;
    }
  }

  Color get iconColor {
    switch (this) {
      case NotificationType.info:
        return CategoryAccent.tech;
      case NotificationType.success:
        return CategoryAccent.sports;
      case NotificationType.warning:
        return AppColors.curation;
      case NotificationType.error:
        return CategoryAccent.news;
      case NotificationType.newArticle:
        return AppColors.curation;
      case NotificationType.breakingNews:
        return CategoryAccent.news;
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
