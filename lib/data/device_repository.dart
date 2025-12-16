/* 
// lib/data/device_repository.dart
import 'package:flutter/foundation.dart'; // <-- для ValueListenable
import 'package:hive_flutter/hive_flutter.dart';

import 'device.dart';

class DeviceRepository {
  static const _boxName = 'devices_box';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Box get _box => Hive.box(_boxName);

  // слухач для ValueListenableBuilder у сторінці
  static ValueListenable<Box> listenable() => _box.listenable();

  static List<Device> loadAll() {
    return _box.values
        .where((v) => v != null)
        .map((v) => Device.fromMap(v as Map))
        .toList();
  }

  static Future<void> upsert(Device device) async {
    await _box.put(device.id, device.toMap());
  }

  static Future<void> delete(String id) async {
    await _box.delete(id);
  }
}
*/
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'device.dart';

class DeviceRepository {
  static const _boxName = 'devices_box';

  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  static Box get _box => Hive.box(_boxName);

  // слухач для ValueListenableBuilder у сторінці
  static ValueListenable<Box> listenable() => _box.listenable();

  static List<Device> loadAll() {
    return _box.values
        .where((v) => v != null)
        .map((v) => Device.fromMap(v as Map))
        .toList();
  }

  static Future<void> upsert(Device device) async {
    await _box.put(device.id, device.toMap());
  }

  static Future<void> delete(String id) async {
    await _box.delete(id);
  }

  static Future<void> clearBox() async {
    await _box.clear();
  }

  // ---------------------------------------------------------
  // ДОДАЙ ЦЕ ↓↓↓
  // ---------------------------------------------------------
  static Future<void> seedIfEmpty() async {
    final existing = loadAll();
    //if (existing.isNotEmpty) return; // якщо вже є — нічого не робимо
    await _box.clear(); // примусово очистити

    // 1-й підключений
    await upsert(
      const Device(
        id: 'dev_1',
        title: 'esp32 living room',
        name: 'esp32_lr',
        password: '1234',
        isConnected: true,
      ),
    );

    // 2-й підключений
    await upsert(
      const Device(
        id: 'dev_2',
        title: 'esp32 car',
        name: 'esp32_car',
        password: 'abcd',
        isConnected: true,
      ),
    );

    // знайдений (але не підключений)
    await upsert(
      const Device(
        id: 'dev_3',
        title: 'esp32 garage',
        name: 'esp32_garage',
        password: '',
        isConnected: false,
      ),
    );
  }
}
