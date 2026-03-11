import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';

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
      duration: const Duration(milliseconds: 350),
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
    setState(() {
      _position += details.delta;
      _rotation = _position.dx * _rotationFactor;
    });
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
    return Semantics(
      button: true,
      label: 'Article card. Swipe right to save, swipe left to dismiss, or tap to view details.',
      onTap: widget.onTap,
child: GestureDetector(
    onPanUpdate: _handlePanUpdate,
    onPanEnd: _handlePanEnd,
    onTapDown: (_) => HapticFeedback.lightImpact(),
    onTap: widget.onTap,
        child: Stack(
          children: [
            // Left swipe background (dismiss)
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  color: AppColors.textSecondary
                      .withOpacity( _position.dx < 0
                          ? _position.dx.abs() / 600
                          : 0),
                  child: _position.dx < -50
                      ? Center(
                          child: Semantics(
                            label: 'Swipe left to dismiss article',
                            child: Transform.rotate(
                              angle: -0.2,
                              child: Icon(
                                Icons.close_rounded,
                                size: 80,
                                color: AppColors.textSecondary.withValues(
                                  alpha: _position.dx.abs().clamp(50.0, 500.0) / 500.0,
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
                  color: AppColors.success
                      .withOpacity( _position.dx > 0
                          ? (_position.dx / 600) * 0.15
                          : 0),
                  child: _position.dx > 50
                      ? Center(
                          child: Semantics(
                            label: 'Swipe right to save article',
                            child: Transform.rotate(
                              angle: 0.2,
                              child: Icon(
                                Icons.favorite_rounded,
                                size: 80,
                                color: AppColors.accent.withValues(
                                  alpha: _position.dx.clamp(50.0, 500.0) / 500.0,
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
                  child: Semantics(
                    container: true,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
