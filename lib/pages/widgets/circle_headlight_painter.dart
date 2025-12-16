import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class CircleHeadlightPainter extends CustomPainter {
  final Color leftColor;
  final Color rightColor;
  final double progress;
  final double leftBrightness;
  final double rightBrightness;
  final bool reverseDirection;

  const CircleHeadlightPainter({
    required this.leftColor,
    required this.rightColor,
    required this.progress,
    required this.leftBrightness,
    required this.rightBrightness,
    this.reverseDirection = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.035;

    _draw(
      canvas,
      Offset(size.width * 0.23, size.height * 0.48),
      r,
      reverseDirection ? -progress : progress,
      leftColor,
      leftBrightness,
    );

    _draw(
      canvas,
      Offset(size.width * 0.79, size.height * 0.48),
      r,
      reverseDirection ? progress : -progress,
      rightColor,
      rightBrightness,
    );
  }

  void _draw(Canvas canvas, Offset c, double r, double p, Color col, double b) {
    if (b <= 0.001) return;

    final paint = Paint()
      ..color = col.withOpacity(0.9 * b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.9
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..blendMode = BlendMode.plus;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2 + p * 2 * math.pi,
      math.pi / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
