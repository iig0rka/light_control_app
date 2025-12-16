import 'dart:math' as math;
import 'package:flutter/material.dart';

class PulsationLayer extends CustomPainter {
  final double phase;
  final Color color;
  final double maxBrightness;
  final bool leftEnabled;
  final bool rightEnabled;

  const PulsationLayer({
    required this.phase,
    required this.color,
    required this.maxBrightness,
    required this.leftEnabled,
    required this.rightEnabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final b = ((math.sin(phase * 2 * math.pi) + 1) / 2) * maxBrightness;
    if (b <= 0.001) return;

    final r = size.width * 0.04;
    if (leftEnabled) {
      _draw(canvas, Offset(size.width * 0.23, size.height * 0.48), r, b);
    }
    if (rightEnabled) {
      _draw(canvas, Offset(size.width * 0.79, size.height * 0.48), r, b);
    }
  }

  void _draw(Canvas canvas, Offset c, double r, double b) {
    final p = Paint()
      ..color = color.withOpacity(0.9 * b)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c, r * 1.4, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
