import 'dart:math';
import 'package:flutter/material.dart';

/// Subtle grain/noise overlay that breaks flat digital sterility.
/// Uses a fixed seed for consistent noise across rebuilds.
class GrainOverlay extends StatelessWidget {
  final double opacity;

  const GrainOverlay({super.key, this.opacity = 0.04});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GrainPainter(opacity: opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  final double opacity;
  static final _random = Random(42);

  _GrainPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final random = _random;
    final paint = Paint();
    const cellSize = 4.0;
    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final value = random.nextDouble();
        if (value > 0.5) {
          paint.color = Colors.white.withValues(
            alpha: (random.nextDouble() * opacity).clamp(0.0, 1.0),
          );
          canvas.drawCircle(
            Offset(x * cellSize + random.nextDouble() * cellSize,
                y * cellSize + random.nextDouble() * cellSize),
            0.5 + random.nextDouble() * 0.5,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => oldDelegate.opacity != opacity;
}
