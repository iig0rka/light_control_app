import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';
import 'headlight_state.dart';

class HeadlightRepository {
  static const _boxName = 'headlight_settings';
  static const _stateKey = 'state';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Box get _box => Hive.box(_boxName);

  /// слухач для ValueListenableBuilder
  static ValueListenable<Box> listenable() => _box.listenable();

  /// зчитати стан (або дефолт, якщо ще нічого нема)
  static HeadlightState load() {
    final raw = _box.get(_stateKey);
    return HeadlightState.fromMap(raw is Map ? raw : <String, dynamic>{});
  }

  /// зберегти стан
  static Future<void> save(HeadlightState state) async {
    await _box.put(_stateKey, state.toMap());
  }

  static Future<void> setLightsEnabled(bool enabled) async {
    final current = load();
    await save(current.copyWith(lightsEnabled: enabled));
  }

  static Future<void> setActiveSource(ActiveModeSource source) async {
    final current = load();
    await save(current.copyWith(activeSource: source));
  }

  // ✅ Коли юзер крутить quick — quick стає головним, preset чистимо
  static Future<void> setActiveQuick() async {
    final current = load();
    await save(
      current.copyWith(
        activeSource: ActiveModeSource.quick,
        activePresetId: null,
      ),
    );
  }

  // ✅ Коли натиснули Set на пресеті — lighting стає головним, запам’ятали preset
  static Future<void> setActiveLightingPreset(String presetId) async {
    final current = load();
    await save(
      current.copyWith(
        activeSource: ActiveModeSource.lighting,
        activePresetId: presetId,
      ),
    );
  }
}
