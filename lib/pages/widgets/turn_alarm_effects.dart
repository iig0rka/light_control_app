import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class HeadlightLayout {
  final Offset leftCenter; // 0..1
  final Offset rightCenter; // 0..1
  final double radiusFactor; // * width

  const HeadlightLayout({
    required this.leftCenter,
    required this.rightCenter,
    required this.radiusFactor,
  });

  static const carSvg = HeadlightLayout(
    leftCenter: Offset(0.23, 0.48),
    rightCenter: Offset(0.79, 0.48),
    radiusFactor: 0.04,
  );

  /// Для превʼю в картці: одна велика фара по центру
  static const singlePreview = HeadlightLayout(
    leftCenter: Offset(0.5, 0.5),
    rightCenter: Offset(0.5, 0.5),
    radiusFactor: 0.3,
  );
}

/// 1) CircleHeadlightPainter (сегмент 1/4, glow)
/// Для turn/emergency можна керувати сторонами через leftEnabled/rightEnabled
class CircleHeadlightPainter extends CustomPainter {
  final Color leftColor;
  final Color rightColor;
  final double progress; // 0..1 – фаза руху
  final double leftBrightness; // 0..1
  final double rightBrightness; // 0..1
  final bool leftEnabled;
  final bool rightEnabled;
  final HeadlightLayout layout;

  const CircleHeadlightPainter({
    required this.leftColor,
    required this.rightColor,
    required this.progress,
    this.leftBrightness = 1.0,
    this.rightBrightness = 1.0,
    this.leftEnabled = true,
    this.rightEnabled = true,
    this.layout = HeadlightLayout.carSvg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftCenter = Offset(
      size.width * layout.leftCenter.dx,
      size.height * layout.leftCenter.dy,
    );
    final rightCenter = Offset(
      size.width * layout.rightCenter.dx,
      size.height * layout.rightCenter.dy,
    );

    final radius = size.width * (layout.radiusFactor * 0.75);

    // базові старти, щоб виглядало як “рух по колу”
    const rightStart = -math.pi / 2; // 12 год
    const leftStart = -3 * math.pi / 3;

    // Ліва: проти год (через -progress)
    if (leftEnabled) {
      _drawArcGlow(
        canvas,
        center: leftCenter,
        radius: radius,
        prog: -progress,
        color: leftColor,
        brightness: leftBrightness,
        startOffset: leftStart,
      );
    }

    // Права: за год (через +progress)
    if (rightEnabled) {
      _drawArcGlow(
        canvas,
        center: rightCenter,
        radius: radius,
        prog: progress,
        color: rightColor,
        brightness: rightBrightness,
        startOffset: rightStart,
      );
    }
  }

  void _drawArcGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double prog,
    required Color color,
    required double brightness,
    required double startOffset,
  }) {
    if (brightness <= 0.001) return;
    const sweep = math.pi / 2; // 1/4 кола
    final startAngle = startOffset + prog * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final glowIntensity = (brightness * 2.2).clamp(0.4, 2.4);
    final glowColor = color.withOpacity(0.9);

    final outerGlow = Paint()
      ..color = glowColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 1.3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawArc(rect, startAngle, sweep, false, outerGlow);

    final midGlow = Paint()
      ..color = glowColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.9
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawArc(rect, startAngle, sweep, false, midGlow);

    final border = Paint()
      ..color = Colors.white.withOpacity(brightness.clamp(0.03, 0.95))
      ..strokeWidth = lerpDouble(3, 6, brightness)!
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.95),
      startAngle,
      sweep,
      false,
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CircleHeadlightPainter old) =>
      old.leftColor != leftColor ||
      old.rightColor != rightColor ||
      old.progress != progress ||
      old.leftBrightness != leftBrightness ||
      old.rightBrightness != rightBrightness ||
      old.leftEnabled != leftEnabled ||
      old.rightEnabled != rightEnabled ||
      old.layout != layout;
}

/// 2) BlinkHeadlightsPainter (обидві або тільки одна сторона)
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

    final leftC = Offset(
      size.width * layout.leftCenter.dx,
      size.height * layout.leftCenter.dy,
    );
    final rightC = Offset(
      size.width * layout.rightCenter.dx,
      size.height * layout.rightCenter.dy,
    );
    final r = size.width * layout.radiusFactor;

    if (leftEnabled) _draw(canvas, leftC, r, b);
    if (rightEnabled) _draw(canvas, rightC, r, b);
  }

  void _draw(Canvas canvas, Offset center, double r, double b) {
    final intensity = b.clamp(0.0, 1.0);

    // 1) круглий glow
    final glowRadius = r * 2;
    final glowPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.85 * intensity),
          color.withOpacity(0.25 * intensity),
          color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

    canvas.drawCircle(center, glowRadius, glowPaint);

    // 2) ядро
    final corePaint = Paint()
      ..blendMode = BlendMode.plus
      ..color = color.withOpacity(0.55 * intensity);
    canvas.drawCircle(center, r * 0.95, corePaint);

    // 3) білий кільцевий контур
    final ring = Paint()
      ..color = Colors.white.withOpacity(
        (0.35 + 0.65 * intensity).clamp(0.0, 1.0),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(1.5, 5.0, intensity)!;

    canvas.drawCircle(center, r * 0.70, ring);
  }

  @override
  bool shouldRepaint(covariant BlinkHeadlightsPainter old) =>
      old.isOn != isOn ||
      old.color != color ||
      old.brightness != brightness ||
      old.leftEnabled != leftEnabled ||
      old.rightEnabled != rightEnabled ||
      old.layout != layout;
}

/// 3) PulsationLayer (плавний синус; можна вимикати сторону)
class PulsationLayer extends StatelessWidget {
  final double phase; // 0..1
  final Color color;
  final double maxBrightness; // 0..1
  final bool leftEnabled;
  final bool rightEnabled;
  final HeadlightLayout layout;

  const PulsationLayer({
    super.key,
    required this.phase,
    required this.color,
    required this.maxBrightness,
    this.leftEnabled = true,
    this.rightEnabled = true,
    this.layout = HeadlightLayout.carSvg,
  });

  @override
  Widget build(BuildContext context) {
    final pulse = (math.sin(phase * 2 * math.pi) + 1) / 2; // 0..1
    final b = (pulse * maxBrightness).clamp(0.0, 1.0);

    return CustomPaint(
      painter: BlinkHeadlightsPainter(
        isOn: b > 0.001,
        color: color,
        brightness: b,
        leftEnabled: leftEnabled,
        rightEnabled: rightEnabled,
        layout: layout,
      ),
    );
  }
}
