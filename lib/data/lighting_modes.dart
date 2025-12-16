import 'package:flutter/material.dart';

enum LightingModeType { circle, rainbow, gradient, blinking, pulsation }

class LightingModeConfig {
  final LightingModeType type;
  final String title;
  final Color color1;
  final Color color2;
  final double speed;
  final double brightness; // 0..1

  const LightingModeConfig({
    required this.type,
    required this.title,
    required this.color1,
    required this.color2,
    required this.speed,
    this.brightness = 1.0,
  });

  LightingModeConfig copyWith({
    LightingModeType? type,
    String? title,
    Color? color1,
    Color? color2,
    double? speed,
    double? brightness,
  }) {
    return LightingModeConfig(
      type: type ?? this.type,
      title: title ?? this.title,
      color1: color1 ?? this.color1,
      color2: color2 ?? this.color2,
      speed: speed ?? this.speed,
      brightness: brightness ?? this.brightness,
    );
  }
}
