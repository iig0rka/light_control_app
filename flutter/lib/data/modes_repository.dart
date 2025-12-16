import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'mode_preset.dart';

class ModesRepository {
  static const _boxName = 'modes_box';

  static const _kLatest = 'latest_ids'; // List<String>
  static String _kCurrent(PresetCategory c) => 'current_${c.name}';
  static String _kFav(String id) => 'fav_$id';
  static String _kPreset(String id) => 'preset_$id';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Box get _box => Hive.box(_boxName);

  static ValueListenable<Box> listenable() => _box.listenable();
  static ModePreset? loadById(String id) {
    final raw = _box.get(_kPreset(id));
    if (raw is! Map) return null;
    return ModePreset.fromMap(raw);
  }

  // ---------- CURRENT ----------
  static Future<void> setCurrent(ModePreset preset) async {
    // 1) store preset
    await _box.put(_kPreset(preset.id), preset.toMap());

    // 2) set current pointer
    await _box.put(_kCurrent(preset.category), preset.id);

    // 3) push to latest
    await _pushLatest(preset.id);
  }

  static ModePreset? loadCurrent(PresetCategory category) {
    final id = _box.get(_kCurrent(category));
    if (id is! String || id.isEmpty) return null;
    final raw = _box.get(_kPreset(id));
    if (raw is! Map) return null;
    return ModePreset.fromMap(raw);
  }

  // ---------- FAVORITES ----------
  static bool isFavorite(String presetId) {
    final v = _box.get(_kFav(presetId));
    return v == true;
  }

  static Future<void> toggleFavorite(String presetId) async {
    final now = !isFavorite(presetId);
    await _box.put(_kFav(presetId), now);

    // якщо пресет вже збережений — оновимо поле isFavorite всередині
    final raw = _box.get(_kPreset(presetId));
    if (raw is Map) {
      final p = ModePreset.fromMap(raw).copyWith(isFavorite: now);
      await _box.put(_kPreset(presetId), p.toMap());
    }
  }

  // ---------- LATEST ----------
  static List<ModePreset> loadLatest10() {
    final ids = _box.get(_kLatest);
    if (ids is! List) return [];
    final out = <ModePreset>[];
    for (final x in ids) {
      if (x is! String) continue;
      final raw = _box.get(_kPreset(x));
      if (raw is Map) out.add(ModePreset.fromMap(raw));
    }
    // newest first already
    return out.take(10).toList();
  }

  static List<ModePreset> loadFavorites() {
    // пробігаємось по latest + по всіх preset_* ключах
    final out = <ModePreset>[];
    for (final k in _box.keys) {
      if (k is! String) continue;
      if (!k.startsWith('preset_')) continue;
      final raw = _box.get(k);
      if (raw is! Map) continue;
      final p = ModePreset.fromMap(raw);
      if (isFavorite(p.id)) out.add(p.copyWith(isFavorite: true));
    }

    out.sort((a, b) => b.savedAtMs.compareTo(a.savedAtMs));
    return out;
  }

  // ---------- INTERNAL ----------
  static Future<void> _pushLatest(String presetId) async {
    final idsRaw = _box.get(_kLatest);
    final ids = (idsRaw is List)
        ? idsRaw.whereType<String>().toList()
        : <String>[];

    ids.removeWhere((x) => x == presetId);
    ids.insert(0, presetId);

    // невеликий буфер, щоб не ріс вічно
    if (ids.length > 50) ids.removeRange(50, ids.length);

    await _box.put(_kLatest, ids);
  }
}
