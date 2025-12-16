import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'headlight_layout.dart';
import 'blink_headlights_painter.dart';

class PulsationLayer extends StatelessWidget {
  final double phase; // 0..1
  final Color color;
  final double maxBrightness; // 0..1
  final HeadlightLayout layout;

  const PulsationLayer({
    super.key,
    required this.phase,
    required this.color,
    required this.maxBrightness,
    this.layout = HeadlightLayout.carSvg,
  });

  @override
  Widget build(BuildContext context) {
    // 0..1
    final pulse = (math.sin(phase * 2 * math.pi) + 1) / 2;
    final b = (pulse * maxBrightness).clamp(0.0, 1.0);

    return CustomPaint(
      painter: BlinkHeadlightsPainter(
        isOn: b > 0.001,
        color: color,
        brightness: b,
        leftEnabled: true,
        rightEnabled: true,
        layout: layout,
      ),
    );
  }
}
