import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../data/lighting_modes.dart';

/// Кадр для авто: колір фар + прогрес 0..1 (для обертання сегмента)
class HeadlightFrame {
  final Color left;
  final Color right;
  final double progress; // 0..1

  const HeadlightFrame({
    required this.left,
    required this.right,
    required this.progress,
  });
  double get phase => progress;
}

/// Розрахунок кадру для поточного режиму
HeadlightFrame buildHeadlightFrame(
  LightingModeConfig mode,
  double controllerValue,
) {
  final t = _time(mode, controllerValue);
  final left = _leftHeadlightColor(mode, t);
  final right = _rightHeadlightColor(mode, t);

  // рух сегмента тільки для Circle, для інших progress = 0
  final progress =
      (mode.type == LightingModeType.circle ||
          mode.type == LightingModeType.rainbow ||
          mode.type == LightingModeType.gradient)
      ? t
      : 0.0;

  return HeadlightFrame(left: left, right: right, progress: progress);
}

// ---------- ВНУТРІШНЯ ЛОГІКА ЕФЕКТІВ ----------

double _time(LightingModeConfig mode, double controllerValue) =>
    (controllerValue * (1 + mode.speed * 3)) % 1.0;

/// Базовий колір у момент t
Color _colorForTimeCircle(LightingModeConfig mode, double t) {
  switch (mode.type) {
    case LightingModeType.circle:
      return mode.color1;

    case LightingModeType.rainbow:
      final hsv = HSVColor.fromAHSV(1.0, t * 360.0, 1.0, 1.0);
      return hsv.toColor();

    case LightingModeType.gradient:
      return Color.lerp(
        mode.color1,
        mode.color2,
        (math.sin(t * math.pi * 2) + 1) / 2,
      )!;

    case LightingModeType.blinking:
    case LightingModeType.pulsation:
      return mode.color1;
  }
}

/// Яскравість у момент t, з урахуванням повзунка brightness
double _brightnessForTime(LightingModeConfig mode, double t) {
  switch (mode.type) {
    case LightingModeType.blinking:
      // speed: 0..1 -> 1..10 Hz
      final freq = 1 + mode.speed * 9;
      final period = 1 / freq;

      final isOn = (t % period) < (period / 2);
      return isOn ? mode.brightness : 0.0;

    case LightingModeType.pulsation:
      final v = (math.sin(t * math.pi * 2) + 1) / 2;
      return v * mode.brightness;

    default:
      return mode.brightness;
  }
}

Color _withBrightness(Color base, double brightness) {
  final hsv = HSVColor.fromColor(base);
  return hsv.withValue(brightness.clamp(0.0, 1.0)).toColor();
}

Color _leftHeadlightColor(LightingModeConfig mode, double t) {
  final c = _colorForTimeCircle(mode, t);
  final b = _brightnessForTime(mode, t);
  return _withBrightness(c, b);
}

Color _rightHeadlightColor(LightingModeConfig mode, double t) {
  final tOpposite = (1.0 - t) % 1.0;
  final c = _colorForTimeCircle(mode, tOpposite);
  final b = _brightnessForTime(mode, tOpposite);
  return _withBrightness(c, b);
}
