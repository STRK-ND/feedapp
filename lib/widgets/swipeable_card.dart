import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

/// Swipeable card widget for article cards
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final VoidCallback onTap;
  final double swipeThreshold;

  const SwipeableCard({
    required this.child,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onTap,
    this.swipeThreshold = 150.0,
    super.key,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  static const double _rotationFactor = 0.015;

  // Use ValueNotifier for position to reduce rebuilds
  final ValueNotifier<Offset> _positionNotifier = ValueNotifier(Offset.zero);
  final ValueNotifier<double> _rotationNotifier = ValueNotifier(0.0);

  late final AnimationController _controller;
  VoidCallback? _animationListener;

  Offset _position = Offset.zero;
  double _rotation = 0.0;
  bool _isAnimatingOut = false;
  Animation<Offset>? _animation;
  Animation<double>? _rotationAnimation;

  @override
  void initState() {
    super.initState();
    // Use reduced duration if user prefers reduced motion
    final duration = Helpers.getAnimationDuration(
      const Duration(milliseconds: 350),
      reducedDuration: const Duration(milliseconds: 150),
    );
    _controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    _controller.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  void dispose() {
    // Memory leak fix: Explicitly remove all listeners before disposing
    if (_animation != null && _animationListener != null) {
      _animation!.removeListener(_animationListener!);
    }
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isAnimatingOut) {
      final direction = _position.dx > 0 ? 'right' : 'left';
      if (direction == 'right') {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
      setState(() {
        _position = Offset.zero;
        _rotation = 0.0;
        _isAnimatingOut = false;
      });
    } else if (status == AnimationStatus.completed) {
      setState(() {
        _position = Offset.zero;
        _rotation = 0.0;
      });
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isAnimatingOut) return;
    _position += details.delta;
    _rotation = _position.dx * _rotationFactor;

    // Update ValueNotifiers instead of setState for better performance
    _positionNotifier.value = _position;
    _rotationNotifier.value = _rotation;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isAnimatingOut) return;

    if (_position.dx.abs() > widget.swipeThreshold) {
      _animateOut();
    } else {
      _animateBack();
    }

    if (_position.dy.abs() > widget.swipeThreshold) {
      _animateBack();
    }
  }

  void _animateOut() {
    setState(() {
      _isAnimatingOut = true;
    });

    _controller.reset();
    _controller.forward().then((_) {
      final direction = _position.dx > 0 ? 'right' : 'left';
      if (direction == 'right') {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
      setState(() {
        _position = Offset.zero;
        _rotation = 0.0;
        _isAnimatingOut = false;
      });
    });
  }

  void _animateBack() {
    // Store old animation to remove its listener
    final oldAnimation = _animation;
    final oldListener = _animationListener;

    _animation = Tween<Offset>(
      begin: _position,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _rotationAnimation = Tween<double>(
      begin: _rotation,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.reset();

    // Remove old listener if exists to prevent memory leak
    if (oldAnimation != null && oldListener != null) {
      oldAnimation.removeListener(oldListener);
    }

    _animationListener = () {
      if (mounted) {
        _position = _animation!.value;
        _rotation = _rotationAnimation!.value;
        // Update ValueNotifiers to trigger rebuilds
        _positionNotifier.value = _position;
        _rotationNotifier.value = _rotation;
      }
    };

    _animation!.addListener(_animationListener!);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: 'Article card. Swipe right to save, swipe left to dismiss, or tap to view details.',
        onTap: widget.onTap,
        child: GestureDetector(
          onPanUpdate: _handlePanUpdate,
          onPanEnd: _handlePanEnd,
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: TinderTheme.bgMedium.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Left swipe background (dismiss) - refined styling
                ValueListenableBuilder<Offset>(
                valueListenable: _positionNotifier,
                builder: (context, position, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final swipeAlpha = position.dx < 0
                          ? (position.dx.abs() / 200).clamp(0.0, 0.12)
                          : 0.0;

                      return Container(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        decoration: BoxDecoration(
                          color: AppColors.swipeDismiss.withValues(alpha: swipeAlpha),
                          borderRadius: BorderRadius.circular(AppDimens.cardCornerRadius),
                        ),
                        child: position.dx < -50
                            ? Center(
                                child: Semantics(
                                  label: 'Swipe left to dismiss article',
                                  child: Transform.rotate(
                                    angle: -0.15,
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface.withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.swipeDismiss.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 40,
                                        color: AppColors.swipeDismiss.withValues(
                                          alpha: (position.dx.abs() / 150).clamp(0.3, 1.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),

              // Right swipe background (save) - refined styling
              ValueListenableBuilder<Offset>(
                valueListenable: _positionNotifier,
                builder: (context, position, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final swipeAlpha = position.dx > 0
                          ? (position.dx / 200).clamp(0.0, 0.12)
                          : 0.0;

                      return Container(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        decoration: BoxDecoration(
                          color: AppColors.swipeSave.withValues(alpha: swipeAlpha),
                          borderRadius: BorderRadius.circular(AppDimens.cardCornerRadius),
                        ),
                        child: position.dx > 50
                            ? Center(
                                child: Semantics(
                                  label: 'Swipe right to save article',
                                  child: Transform.rotate(
                                    angle: 0.15,
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface.withValues(alpha: 0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.swipeSave.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.bookmark_added_rounded,
                                        size: 40,
                                        color: AppColors.swipeSave.withValues(
                                          alpha: (position.dx / 150).clamp(0.3, 1.0),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),

              // Card content with swipe transformation
              ValueListenableBuilder<Offset>(
                valueListenable: _positionNotifier,
                builder: (context, position, child) {
                  return ValueListenableBuilder<double>(
                    valueListenable: _rotationNotifier,
                    builder: (context, rotation, child) {
                      return Positioned.fill(
                        child: Transform.translate(
                          offset: position,
                          child: Transform.rotate(
                            angle: rotation,
                            child: Semantics(
                              container: true,
                              child: widget.child,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
