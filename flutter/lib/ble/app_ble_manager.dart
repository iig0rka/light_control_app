import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../data/device_repository.dart';
import 'ble_device_store.dart';

class AppBleManager {
  AppBleManager._();
  static final I = AppBleManager._();

  Timer? _ticker;
  bool _busy = false;

  String? _targetDeviceId;
  String? _password;

  /// UI може підписатися (сіре авто / reconnect state)
  final ValueNotifier<bool> autoReconnecting = ValueNotifier<bool>(false);

  // ================== PUBLIC API ==================

  Future<void> start() async {
    debugPrint('[AUTO] start');

    // беремо останній підключений девайс з Hive
    final saved = DeviceRepository.loadAll()
        .where((d) => d.isConnected)
        .toList();

    if (saved.isNotEmpty) {
      _targetDeviceId = saved.first.id;
      _password = saved.first.password;
      debugPrint('[AUTO] target=$_targetDeviceId');
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 5), (_) => tick());

    // одразу пробуємо
    await tick();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// викликати після ручного connect у ConnectDevicePage
  void setLastConnected({required String deviceId, required String password}) {
    _targetDeviceId = deviceId;
    _password = password;
    debugPrint('[AUTO] lastConnected set: $deviceId');
  }

  // ================== CORE LOOP ==================

  Future<void> tick() async {
    if (_busy) return;
    _busy = true;

    try {
      final active = BleDeviceStore.I.device.value;
      final connected = BleDeviceStore.I.isConnected.value;

      // вже підключено — нічого не робимо
      if (active != null && connected) {
        autoReconnecting.value = false;
        return;
      }

      if (_targetDeviceId == null) {
        autoReconnecting.value = false;
        return;
      }

      autoReconnecting.value = true;
      debugPrint('[AUTO] scanning for $_targetDeviceId');

      final hit = await _scanForTarget(_targetDeviceId!);
      if (hit == null) {
        debugPrint('[AUTO] device not found');
        return;
      }

      final d = hit.device;

      final st = await d.connectionState.first;
      if (st != BluetoothConnectionState.connected) {
        debugPrint('[AUTO] connecting...');
        await d.connect(timeout: const Duration(seconds: 10));
      }

      final ok = await _auth(d, _password ?? '');
      if (!ok) {
        debugPrint('[AUTO] auth failed');
        try {
          await d.disconnect();
        } catch (_) {}
        return;
      }

      BleDeviceStore.I.setDevice(d);
      debugPrint('[AUTO] connected & active ✅');
    } catch (e) {
      debugPrint('[AUTO] error: $e');
    } finally {
      _busy = false;
    }
  }

  // ================== SCAN ==================

  Future<ScanResult?> _scanForTarget(String targetId) async {
    ScanResult? hit;

    late final StreamSubscription sub;
    sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.remoteId.str == targetId) {
          hit = r;
          debugPrint('[AUTO] found target!');
          sub.cancel();
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
      await Future.delayed(const Duration(seconds: 3));
    } finally {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
    }

    return hit;
  }

  // ================== AUTH ==================

  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const String authCharUuid = 'c0de0001-1fb5-459e-8fcc-c5c9c331914b';

  Future<bool> _auth(BluetoothDevice device, String password) async {
    final services = await device.discoverServices();

    final svc = services.firstWhere(
      (s) => s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase(),
      orElse: () => throw Exception('service not found'),
    );

    final chr = svc.characteristics.firstWhere(
      (c) => c.uuid.toString().toLowerCase() == authCharUuid.toLowerCase(),
      orElse: () => throw Exception('auth char not found'),
    );

    await chr.write(password.codeUnits, withoutResponse: false);

    try {
      final resp = await chr.read();
      final s = String.fromCharCodes(resp).trim();
      debugPrint('[AUTO] auth resp="$s"');
      return s == 'OK';
    } catch (_) {
      return false;
    }
  }
}
