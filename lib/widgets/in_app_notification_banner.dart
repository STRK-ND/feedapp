import 'dart:async';
import 'package:flutter/material.dart';
import '../models/in_app_notification.dart';
import '../services/in_app_notification_manager.dart';

/// Widget that displays an in-app notification banner
class InAppNotificationBanner extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDismissed;

  const InAppNotificationBanner({
    super.key,
    required this.notification,
    required this.onDismissed,
  });

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
    _startDismissTimer();
  }

  void _startDismissTimer() {
    _dismissTimer?.cancel();
    _progressController.forward(from: 0);
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      if (!_isHovering && mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    _dismissTimer?.cancel();
    _progressController.stop();
    try {
      await _controller.reverse();
    } catch (e) {
      // Ignore TickerCanceled or other animation errors
    }
    if (mounted) {
      widget.onDismissed();
    }
  }

  void _onTap() {
    widget.notification.onTap?.call();
    _dismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController.dispose();
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = widget.notification.type;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutBack,
          )),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: _onTap,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity!.abs() > 100) {
                  _dismiss();
                }
              },
              child: MouseRegion(
                onEnter: (_) {
                  setState(() => _isHovering = true);
                  _dismissTimer?.cancel();
                  _progressController.stop();
                },
                onExit: (_) {
                  setState(() => _isHovering = false);
                  _startDismissTimer();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: type.backgroundColor.withValues(alpha:0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                        spreadRadius: -8,
                      ),
                    ],
                    border: Border.all(
                      color: type.backgroundColor.withValues(alpha:0.2),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress bar - synchronized with dismiss timer
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return LinearProgressIndicator(
                              value: _isHovering ? null : _progressController.value,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                type.backgroundColor.withValues(alpha:0.6),
                              ),
                              minHeight: 3,
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: type.backgroundColor.withValues(alpha:0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  type.icon,
                                  color: type.iconColor,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.notification.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1A1A),
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.notification.body,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF666666),
                                        height: 1.4,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Dismiss button
                              GestureDetector(
                                onTap: _dismiss,
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha:0.05)
                                        : Colors.black.withValues(alpha:0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Overlay widget that displays in-app notifications on top of the app
class InAppNotificationOverlay extends StatefulWidget {
  final Widget child;

  const InAppNotificationOverlay({
    super.key,
    required this.child,
  });

  @override
  State<InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay> {
  final List<InAppNotification> _activeNotifications = [];
  StreamSubscription<InAppNotification>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = InAppNotificationManager().notificationStream.listen(_addNotification);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _addNotification(InAppNotification notification) {
    setState(() {
      _activeNotifications.add(notification);
    });
  }

  void _removeNotification(String id) {
    setState(() {
      _activeNotifications.removeWhere((n) => n.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Notification banners positioned at top
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _activeNotifications
                  .take(3) // Show max 3 notifications
                  .map(
                    (notification) => InAppNotificationBanner(
                      key: ValueKey(notification.id),
                      notification: notification,
                      onDismissed: () => _removeNotification(notification.id),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
