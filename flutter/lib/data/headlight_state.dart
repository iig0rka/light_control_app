import 'package:flutter/material.dart';

enum ActiveModeSource { quick, lighting }

class HeadlightState {
  final Color leftColor;
  final Color rightColor;
  final double leftBrightness; // 0..1
  final double rightBrightness; // 0..1
  final bool lightsEnabled;

  final ActiveModeSource activeSource;

  /// null => quick керує
  final String? activePresetId;

  const HeadlightState({
    required this.leftColor,
    required this.rightColor,
    required this.leftBrightness,
    required this.rightBrightness,
    required this.lightsEnabled,
    required this.activeSource,
    this.activePresetId,
  });

  HeadlightState copyWith({
    Color? leftColor,
    Color? rightColor,
    double? leftBrightness,
    double? rightBrightness,
    bool? lightsEnabled,
    ActiveModeSource? activeSource,
    String? activePresetId,
    bool clearActivePresetId = false,
  }) {
    return HeadlightState(
      leftColor: leftColor ?? this.leftColor,
      rightColor: rightColor ?? this.rightColor,
      leftBrightness: leftBrightness ?? this.leftBrightness,
      rightBrightness: rightBrightness ?? this.rightBrightness,
      lightsEnabled: lightsEnabled ?? this.lightsEnabled,
      activeSource: activeSource ?? this.activeSource,
      activePresetId: clearActivePresetId
          ? null
          : (activePresetId ?? this.activePresetId),
    );
  }

  Map<String, dynamic> toMap() => {
    'leftColor': leftColor.value,
    'rightColor': rightColor.value,
    'leftBrightness': leftBrightness,
    'rightBrightness': rightBrightness,
    'lightsEnabled': lightsEnabled,
    'activeSource': activeSource.name,
    'activePresetId': activePresetId,
  };

  static HeadlightState fromMap(Map m) {
    final srcStr = (m['activeSource'] ?? 'quick').toString();
    final src = ActiveModeSource.values.firstWhere(
      (e) => e.name == srcStr,
      orElse: () => ActiveModeSource.quick,
    );

    double asDouble(dynamic v, double def) {
      if (v is num) return v.toDouble();
      return def;
    }

    return HeadlightState(
      leftColor: Color(
        (m['leftColor'] ?? const Color(0xFFFF66FF).value) as int,
      ),
      rightColor: Color(
        (m['rightColor'] ?? const Color(0xFFFF6666).value) as int,
      ),
      leftBrightness: asDouble(m['leftBrightness'], 0.8).clamp(0.0, 1.0),
      rightBrightness: asDouble(m['rightBrightness'], 0.8).clamp(0.0, 1.0),
      lightsEnabled: (m['lightsEnabled'] ?? true) as bool,
      activeSource: src,
      activePresetId: (m['activePresetId'] as String?),
    );
  }
}
