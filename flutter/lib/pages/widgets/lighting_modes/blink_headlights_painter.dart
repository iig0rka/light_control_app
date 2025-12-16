import 'dart:ui';
import 'package:flutter/material.dart';

import 'headlight_layout.dart';

class BlinkHeadlightsPainter extends CustomPainter {
  final bool isOn;
  final Color color;
  final double brightness; // 0..1
  final bool leftEnabled;
  final bool rightEnabled;
  final HeadlightLayout layout;

  const BlinkHeadlightsPainter({
    required this.isOn,
    required this.color,
    required this.brightness,
    this.leftEnabled = true,
    this.rightEnabled = true,
    this.layout = HeadlightLayout.carSvg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final b = brightness.clamp(0.0, 1.0);
    if (!isOn || b <= 0.001) return;

    final leftCenter = Offset(
      size.width * layout.leftCenter.dx,
      size.height * layout.leftCenter.dy,
    );
    final rightCenter = Offset(
      size.width * layout.rightCenter.dx,
      size.height * layout.rightCenter.dy,
    );
    final r = size.width * layout.radiusFactor;

    if (leftEnabled) _drawHeadlight(canvas, leftCenter, r, b);
    if (rightEnabled) _drawHeadlight(canvas, rightCenter, r, b);
  }

  void _drawHeadlight(Canvas canvas, Offset center, double r, double b) {
    final clipRect = Rect.fromCircle(center: center, radius: r * 2);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(clipRect, Radius.circular(r)));

    final glowIntensity = b * 2.2;

    final innerGlow = Paint()
      ..color = color.withOpacity(0.95 * b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(center, r * 0.9, innerGlow);

    final ring = Paint()
      ..color = Colors.white.withOpacity((0.35 + 0.65 * b).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(1.5, 5.0, b)!;

    canvas.drawCircle(center, r * 0.70, ring);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BlinkHeadlightsPainter old) =>
      old.isOn != isOn ||
      old.color != color ||
      old.brightness != brightness ||
      old.leftEnabled != leftEnabled ||
      old.rightEnabled != rightEnabled;
}
