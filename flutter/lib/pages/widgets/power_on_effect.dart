import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import 'turn_alarm_effects.dart'; // HeadlightLayout + BlinkHeadlightsPainter

// ---- helpers ----
double _lerp(double a, double b, double t) => a + (b - a) * t;

/// 1) Triple blink on/off (3 моргання, потім пауза, повтор)
/// periodSec — довжина одного моргання (ON+OFF) по часу
/// duty — частка ON усередині periodSec (0.5 = 50%)
///
bool tripleBlinkOn(
  double tSec, {
  double periodSec = 0.6,
  double duty = 0.5,
  int blinks = 3,
  double gapSec = 0.9,
}) {
  final total = blinks * periodSec + gapSec;
  final local = tSec % total;
  if (local >= blinks * periodSec) return false;

  final phase = local % periodSec;
  return phase < (periodSec * duty);
}

/// 2) Fill ring: сегмент росте від малого до повного кола за fillSec
/// leftDirectionCCW=true => ліва “заливається” уліво (проти год)
class FillRingPainter extends CustomPainter {
  final Color color;
  final double progress01; // 0..1
  final double brightness; // 0..1
  final bool leftEnabled;
  final bool rightEnabled;
  final HeadlightLayout layout;

  /// стартові кути (можеш підкрутити, якщо треба)
  final double leftStartAngle;
  final double rightStartAngle;

  const FillRingPainter({
    required this.color,
    required this.progress01,
    required this.brightness,
    this.leftEnabled = true,
    this.rightEnabled = true,
    this.layout = HeadlightLayout.carSvg,
    this.leftStartAngle = -math.pi / 2, // зверху
    this.rightStartAngle = -math.pi / 2, // зверху
  });

  @override
  void paint(Canvas canvas, Size size) {
    final b = brightness.clamp(0.0, 1.0);
    if (b <= 0.001) return;

    final leftC = Offset(
      size.width * layout.leftCenter.dx,
      size.height * layout.leftCenter.dy,
    );
    final rightC = Offset(
      size.width * layout.rightCenter.dx,
      size.height * layout.rightCenter.dy,
    );

    final r = size.width * (layout.radiusFactor * 0.75);
    final sweep = _lerp(0.12, 2 * math.pi, progress01.clamp(0.0, 1.0));

    // права: clockwise (позитивний sweep)
    if (rightEnabled) {
      _drawArcGlow(
        canvas,
        center: rightC,
        radius: r,
        startAngle: rightStartAngle,
        sweepAngle: sweep,
        color: color,
        b: b,
      );
    }

    // ліва: CCW (негативний sweep) — “у ліву сторону”
    if (leftEnabled) {
      _drawArcGlow(
        canvas,
        center: leftC,
        radius: r,
        startAngle: leftStartAngle,
        sweepAngle: -sweep,
        color: color,
        b: b,
      );
    }
  }

  void _drawArcGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double startAngle,
    required double sweepAngle,
    required Color color,
    required double b,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final glowIntensity = (b * 2.2).clamp(0.4, 2.4);

    // зовнішній glow
    final outer = Paint()
      ..color = color.withOpacity(0.55 * b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 1.25
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawArc(rect, startAngle, sweepAngle, false, outer);

    // середній
    final mid = Paint()
      ..color = color.withOpacity(0.50 * b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.90
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawArc(rect, startAngle, sweepAngle, false, mid);

    // білий контур
    final border = Paint()
      ..color = Colors.white.withOpacity((0.15 + 0.70 * b).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(2.0, 6.0, b)!;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.97),
      startAngle,
      sweepAngle,
      false,
      border,
    );
  }

  @override
  bool shouldRepaint(covariant FillRingPainter old) =>
      old.color != color ||
      old.progress01 != progress01 ||
      old.brightness != brightness ||
      old.leftEnabled != leftEnabled ||
      old.rightEnabled != rightEnabled ||
      old.layout != layout ||
      old.leftStartAngle != leftStartAngle ||
      old.rightStartAngle != rightStartAngle;
}

/// 3) Fade-in: плавне наростання glow (використовує BlinkHeadlightsPainter)
class FadeInLayer extends StatelessWidget {
  final double progress01; // 0..1
  final Color color;
  final bool leftEnabled;
  final bool rightEnabled;
  final HeadlightLayout layout;

  const FadeInLayer({
    super.key,
    required this.progress01,
    required this.color,
    this.leftEnabled = true,
    this.rightEnabled = true,
    this.layout = HeadlightLayout.carSvg,
  });

  @override
  Widget build(BuildContext context) {
    final b = progress01.clamp(0.0, 1.0);
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
