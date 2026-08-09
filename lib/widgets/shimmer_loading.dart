import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Shimmer effect widget for loading states
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({super.key, required this.child, this.isLoading = true});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    final isDesktop =
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.linux;
    final prefersReducedMotion = isDesktop
        ? false
        : mediaQuery?.disableAnimations ?? false;

    if (prefersReducedMotion || !widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainerHighest,
                colorScheme.surfaceContainerHigh,
                colorScheme.surfaceContainerHighest,
              ],
              stops: [0.0, _animation.value.clamp(0.0, 1.0), 1.0],
              transform: _SlidingGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: widget.child,
        );
      },
    );
  }
}

/// Custom gradient transform for sliding effect
class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// Skeleton placeholder box with rounded corners
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Article card skeleton placeholder
class ArticleCardSkeleton extends StatelessWidget {
  final bool isExpanded;

  const ArticleCardSkeleton({super.key, this.isExpanded = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ShimmerLoading(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppCardStyles.cardRadius),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            if (isExpanded)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source row
                  const Row(
                    children: [
                      SkeletonBox(width: 80, height: 24, borderRadius: 12),
                      SizedBox(width: 12),
                      SkeletonBox(width: 60, height: 20, borderRadius: 10),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title lines
                  const SkeletonBox(
                    width: double.infinity,
                    height: 20,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 200, height: 20, borderRadius: 4),
                  const SizedBox(height: 16),

                  // Description lines
                  const SkeletonBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 6),
                  const SkeletonBox(
                    width: double.infinity,
                    height: 14,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 150, height: 14, borderRadius: 4),

                  if (isExpanded) ...[
                    const SizedBox(height: 16),
                    const SkeletonBox(
                      width: double.infinity,
                      height: 14,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 6),
                    const SkeletonBox(
                      width: double.infinity,
                      height: 14,
                      borderRadius: 4,
                    ),
                    const SizedBox(height: 6),
                    const SkeletonBox(width: 180, height: 14, borderRadius: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card stack skeleton for loading state
class CardStackSkeleton extends StatelessWidget {
  final int count;

  const CardStackSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => Transform.scale(
          scale: 1.0 - (index * 0.05),
          child: Transform.translate(
            offset: Offset(0, index * -8.0),
            child: Opacity(
              opacity: 1.0 - (index * 0.2),
              child: const ArticleCardSkeleton(),
            ),
          ),
        ),
      ).reversed.toList(),
    );
  }
}

/// List item skeleton for list view
class ListItemSkeleton extends StatelessWidget {
  const ListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: const Row(
          children: [
            // Thumbnail placeholder
            SkeletonBox(width: 80, height: 80, borderRadius: 12),
            SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 60, height: 18, borderRadius: 8),
                  SizedBox(height: 8),
                  SkeletonBox(
                    width: double.infinity,
                    height: 16,
                    borderRadius: 4,
                  ),
                  SizedBox(height: 6),
                  SkeletonBox(width: 150, height: 14, borderRadius: 4),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      SkeletonBox(width: 80, height: 12, borderRadius: 6),
                      Spacer(),
                      SkeletonBox(width: 24, height: 24, borderRadius: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Feed loading skeleton with multiple list items
/// Full-screen loading skeleton for card view (default)
class FeedLoadingSkeleton extends StatelessWidget {
  final int itemCount;

  const FeedLoadingSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: CardStackSkeleton(count: itemCount),
      ),
    );
  }
}
