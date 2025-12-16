import 'package:flutter/material.dart';

enum PresetCategory { lighting, powerOn, turn, alarm }

class ModePreset {
  const ModePreset({
    required this.id,
    required this.category,
    required this.title,
    this.type = '', // ✅ NEW
    required this.effectId,
    required this.speed,
    required this.brightness,
    required this.color,
    required this.savedAtMs,
    this.isFavorite = false,
  });

  final String id;
  final PresetCategory category;
  final String title;

  /// Напр. "tripleBlink" / "fillRing" / "fadeIn" / або "static"/"circle" тощо
  /// Для lighting можеш класти effectId як source-of-truth, а type = effectName (опційно)
  final String type; // ✅ NEW

  /// 0..255 (твій ESP: 0 static, 1 circle, 2 blink, 3 pulse, 4 rainbow, 5 chase)
  final int effectId;

  /// 0..255
  final int speed;

  /// 0..255
  final int brightness;

  /// колір (для rainbow можна зберігати, але ESP може ігнорити)
  final Color color;

  /// timestamp для latest
  final int savedAtMs;

  final bool isFavorite;

  ModePreset copyWith({
    String? id,
    PresetCategory? category,
    String? title,
    String? type, // ✅ NEW
    int? effectId,
    int? speed,
    int? brightness,
    Color? color,
    int? savedAtMs,
    bool? isFavorite,
  }) {
    return ModePreset(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      type: type ?? this.type, // ✅ NEW
      effectId: effectId ?? this.effectId,
      speed: speed ?? this.speed,
      brightness: brightness ?? this.brightness,
      color: color ?? this.color,
      savedAtMs: savedAtMs ?? this.savedAtMs,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'category': category.name,
    'title': title,
    'type': type, // ✅ NEW
    'effectId': effectId,
    'speed': speed,
    'brightness': brightness,
    'color': color.value,
    'savedAtMs': savedAtMs,
    'isFavorite': isFavorite,
  };

  static ModePreset fromMap(Map m) {
    final catStr = (m['category'] ?? 'lighting').toString();
    final cat = PresetCategory.values.firstWhere(
      (e) => e.name == catStr,
      orElse: () => PresetCategory.lighting,
    );

    return ModePreset(
      id: (m['id'] ?? '').toString(),
      category: cat,
      title: (m['title'] ?? '').toString(),
      type: (m['type'] ?? '').toString(), // ✅ NEW (беккомпат)
      effectId: (m['effectId'] ?? 0) as int,
      speed: (m['speed'] ?? 128) as int,
      brightness: (m['brightness'] ?? 255) as int,
      color: Color((m['color'] ?? Colors.orange.value) as int),
      savedAtMs: (m['savedAtMs'] ?? 0) as int,
      isFavorite: (m['isFavorite'] ?? false) as bool,
    );
  }
}
