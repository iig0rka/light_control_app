import 'dart:ui';

import 'package:flutter/material.dart';

class HeadlightGlow extends StatelessWidget {
  final Rect rect;
  final Color color;
  final bool isActive;
  final double brightness;

  const HeadlightGlow({
    super.key,
    required this.rect,
    required this.color,
    required this.isActive,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: CustomPaint(
          painter: HeadlightGlowPainter(
            color: color,
            isActive: isActive,
            brightness: brightness,
          ),
        ),
      ),
    );
  }
}

class HeadlightGlowPainter extends CustomPainter {
  final Color color;
  final bool isActive;
  final double brightness;

  const HeadlightGlowPainter({
    required this.color,
    required this.isActive,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.13;

    final glowIntensity = (brightness * 2.2).clamp(0.4, 2.4);
    final glowColor = color.withOpacity(isActive ? 0.9 : 0.5);

    // зовнішній шар
    final outerGlow = Paint()
      ..color = glowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(center, baseRadius * 2.5, outerGlow);

    // середній шар
    final midGlow = Paint()
      ..color = glowColor.withOpacity(0.8)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(center, baseRadius * 1.4, midGlow);

    // внутрішній шар
    final innerGlow = Paint()
      ..color = glowColor.withOpacity(0.9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(center, baseRadius * 0.9, innerGlow);

    // біле кільце, яскравість залежить від brightness
    final border = Paint()
      ..color = Colors.white.withOpacity(brightness.clamp(0.03, 0.95))
      ..strokeWidth = lerpDouble(3, 7, brightness)!
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, baseRadius, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
