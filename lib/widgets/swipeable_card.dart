import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

/// Smooth swipeable card widget for article cards.
/// Low swipe threshold (~80px) for easy, fluid swiping.
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
    this.swipeThreshold = 80.0,
    super.key,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  static const double _rotationFactor = 0.01;
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _controller.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  void dispose() {
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
      // A completed swipe is a committed triage action — confirm it
      // physically, not just visually (save right / dismiss left).
      unawaited(HapticFeedback.mediumImpact());
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
    setState(() {
      // Multiply delta for 1:1 tracking (1px drag = 1px card movement)
      _position += details.delta;
      _rotation = _position.dx * _rotationFactor;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_isAnimatingOut) return;

    // If drag is primarily vertical, always snap back
    if (_position.dy.abs() > _position.dx.abs()) {
      _animateBack();
      return;
    }

    // Use velocity for smarter swipe detection
    final velocity = details.velocity.pixelsPerSecond.dx.abs();
    final hasEnoughVelocity = velocity > 600;

    if (_position.dx.abs() > widget.swipeThreshold || hasEnoughVelocity) {
      _animateOut();
    } else {
      _animateBack();
    }
  }

  void _animateOut() {
    setState(() {
      _isAnimatingOut = true;
    });

    _controller.reset();
    _controller.forward();
  }

  void _animateBack() {
    final oldAnimation = _animation;
    final oldListener = _animationListener;

    // Reuse existing Tween objects — only change begin values
    _animation = Tween<Offset>(
      begin: _position,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _rotationAnimation = Tween<double>(
      begin: _rotation,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.reset();

    if (oldAnimation != null && oldListener != null) {
      oldAnimation.removeListener(oldListener);
    }

    _animationListener = () {
      if (mounted) {
        setState(() {
          _position = _animation!.value;
          _rotation = _rotationAnimation!.value;
        });
      }
    };

    _animation!.addListener(_animationListener!);
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          'Article card. Swipe right to save, swipe left to dismiss, or tap to view details.',
      onTap: widget.onTap,
      child: GestureDetector(
        onPanUpdate: _handlePanUpdate,
        onPanEnd: _handlePanEnd,
        onTapDown: (_) => HapticFeedback.selectionClick(),
        onTap: widget.onTap,
        child: Stack(
          children: [
            // Left swipe background (dismiss)
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: _position.dx < 0 ? _position.dx.abs() / 400 : 0,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppCardStyles.cardRadius,
                    ),
                  ),
                  child: _position.dx < -40
                      ? Center(
                          child: Semantics(
                            label: 'Swipe left to dismiss article',
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Icon(
                                Icons.close_rounded,
                                size: 80,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha:
                                      _position.dx.abs().clamp(40.0, 400.0) /
                                      400.0,
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),

            // Right swipe background (save)
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(
                      alpha: _position.dx > 0 ? (_position.dx / 400) * 0.12 : 0,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppCardStyles.cardRadius,
                    ),
                  ),
                  child: _position.dx > 40
                      ? Center(
                          child: Semantics(
                            label: 'Swipe right to save article',
                            child: Transform.rotate(
                              angle: 0.2,
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 80,
                                color: colorScheme.primary.withValues(
                                  alpha:
                                      _position.dx.clamp(40.0, 400.0) / 400.0,
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),

            Positioned.fill(
              child: Transform.translate(
                offset: _position,
                child: Transform.rotate(
                  angle: _rotation,
                  child: Semantics(container: true, child: widget.child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
