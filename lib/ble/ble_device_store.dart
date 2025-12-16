import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceStore {
  BleDeviceStore._();
  static final I = BleDeviceStore._();

  final ValueNotifier<BluetoothDevice?> device = ValueNotifier(null);

  /// ✅ це і є твій isConnected
  final ValueNotifier<bool> isConnected = ValueNotifier(false);

  StreamSubscription<BluetoothConnectionState>? _connSub;

  void setDevice(BluetoothDevice d) {
    device.value = d;

    _connSub?.cancel();
    _connSub = d.connectionState.listen((st) {
      final ok = st == BluetoothConnectionState.connected;
      if (isConnected.value != ok) {
        isConnected.value = ok;
      }

      if (!ok) {
        // якщо хочеш — можеш не чистити device, а лишити як "last known"
        // але для твого "сірого авто" зручніше так:
        device.value = null;
      }
    });
  }

  void clear() {
    _connSub?.cancel();
    _connSub = null;
    device.value = null;
    isConnected.value = false;
  }
}
