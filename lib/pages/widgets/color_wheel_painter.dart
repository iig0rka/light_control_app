import 'package:flutter/material.dart';

class ColorWheelPainter extends CustomPainter {
  const ColorWheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final rect = Rect.fromCircle(center: center, radius: radius);

    const gradient = SweepGradient(
      colors: [
        Color.fromARGB(255, 0, 255, 255),
        Color.fromARGB(255, 0, 0, 255),
        Color.fromARGB(255, 255, 0, 255),
        Color.fromARGB(255, 255, 0, 0),
        Color.fromARGB(255, 255, 255, 0),
        Color.fromARGB(255, 0, 255, 0),
        Color.fromARGB(255, 0, 255, 255),
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);

    final whiteGradient = RadialGradient(
      colors: [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.0)],
      stops: const [0.0, 1.0],
    );

    final whitePaint = Paint()
      ..shader = whiteGradient.createShader(rect)
      ..blendMode = BlendMode.lighten;

    canvas.drawCircle(center, radius, whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
