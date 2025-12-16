import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import 'headlight_layout.dart';

class CircleHeadlightPainter extends CustomPainter {
  final double progress; // 0..1
  final Color leftColor;
  final Color rightColor;
  final double brightness; // 0..1
  final HeadlightLayout layout;

  /// invertDirections=true => left: CCW, right: CW (як ти хочеш для turn/emergency)
  final bool invertDirections;

  const CircleHeadlightPainter({
    required this.progress,
    required this.leftColor,
    required this.rightColor,
    required this.brightness,
    this.layout = HeadlightLayout.carSvg,
    this.invertDirections = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final b = brightness.clamp(0.0, 1.0);
    if (b <= 0.001) return;

    final leftCenter = Offset(
      size.width * layout.leftCenter.dx,
      size.height * layout.leftCenter.dy,
    );
    final rightCenter = Offset(
      size.width * layout.rightCenter.dx,
      size.height * layout.rightCenter.dy,
    );
    final r = size.width * layout.radiusFactor;

    // старт зверху (12 год)
    const startOffset = -math.pi / 2;

    final leftDir = invertDirections ? -1.0 : 1.0;
    final rightDir = invertDirections ? 1.0 : -1.0;

    _drawArc(
      canvas,
      leftCenter,
      r,
      startOffset + leftDir * progress * 2 * math.pi,
      leftColor,
      b,
    );
    _drawArc(
      canvas,
      rightCenter,
      r,
      startOffset + rightDir * progress * 2 * math.pi,
      rightColor,
      b,
    );
  }

  void _drawArc(
    Canvas canvas,
    Offset center,
    double r,
    double angle,
    Color c,
    double b,
  ) {
    const sweep = math.pi / 2; // сегмент 1/4

    // clip щоб glow не розлазився
    final clipRect = Rect.fromCircle(center: center, radius: r * 2);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(clipRect, Radius.circular(r)));

    final glowIntensity = (b * 2.2);

    final innerGlow = Paint()
      ..color = c.withOpacity(0.95 * b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity)
      ..blendMode = BlendMode.plus;

    final ring = Paint()
      ..color = Colors.white.withOpacity((0.35 + 0.65 * b).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(1.5, 5.0, b)!;

    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(rect, angle, sweep, false, innerGlow);
    canvas.drawArc(rect, angle, sweep, false, ring);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CircleHeadlightPainter old) =>
      old.progress != progress ||
      old.leftColor != leftColor ||
      old.rightColor != rightColor ||
      old.brightness != brightness ||
      old.invertDirections != invertDirections;
}
