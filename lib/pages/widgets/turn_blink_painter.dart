import 'dart:ui';
import 'package:flutter/material.dart';

class TurnBlinkPainter extends CustomPainter {
  final bool isOn;
  final bool leftEnabled;
  final bool rightEnabled;
  final Color color;
  final double brightness;

  const TurnBlinkPainter({
    required this.isOn,
    required this.leftEnabled,
    required this.rightEnabled,
    required this.color,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isOn || brightness <= 0.001) return;

    final r = size.width * 0.04;
    if (leftEnabled) {
      _draw(canvas, Offset(size.width * 0.23, size.height * 0.48), r);
    }
    if (rightEnabled) {
      _draw(canvas, Offset(size.width * 0.79, size.height * 0.48), r);
    }
  }

  void _draw(Canvas canvas, Offset c, double r) {
    final p = Paint()
      ..color = color.withOpacity(0.95)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12)
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(c, r * 1.3, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
