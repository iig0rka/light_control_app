import 'dart:async';
import 'dart:developer';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:hive/hive.dart';

class BleConnectionState {
  final bool isConnected;
  final bool isConnecting;
  final BluetoothDevice? device;

  const BleConnectionState({
    this.isConnected = false,
    this.isConnecting = false,
    this.device,
  });

  BleConnectionState copyWith({
    bool? isConnected,
    bool? isConnecting,
    BluetoothDevice? device,
  }) {
    return BleConnectionState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      device: device ?? this.device,
    );
  }
}

class BleConnectionCubit extends Cubit<BleConnectionState> {
  BleConnectionCubit(this._box) : super(const BleConnectionState()) {
    _init();
  }

  final Box _box;
  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  Timer? _reconnectTimer;

  static const String _lastDeviceKey = 'last_device_id';

  Future<void> _init() async {
    final lastId = _box.get(_lastDeviceKey) as String?;
    if (lastId != null) {
      _device = BluetoothDevice.fromId(lastId);
      _listenConnection();
      _startReconnectLoop();
    }
  }

  Future<void> connectTo(BluetoothDevice device) async {
    _device = device;
    _box.put(_lastDeviceKey, device.remoteId.str);
    _listenConnection();
    _startReconnectLoop();

    emit(state.copyWith(
      device: device,
      isConnecting: true,
    ));

    await _tryConnect();
  }

  void _listenConnection() {
    _connSub?.cancel();
    final d = _device;
    if (d == null) return;

    _connSub = d.connectionState.listen((s) {
      log('BLE state: $s');
      if (s == BluetoothConnectionState.connected) {
        emit(state.copyWith(
          isConnected: true,
          isConnecting: false,
          device: d,
        ));
      } else {
        emit(state.copyWith(
          isConnected: false,
          isConnecting: false,
        ));
      }
    });
  }

  Future<void> _tryConnect() async {
    final d = _device;
    if (d == null) return;
    try {
      final st = await d.connectionState.first;
      if (st != BluetoothConnectionState.connected) {
        await d.connect();
      }
    } catch (e) {
      log('Connect error: $e');
    }
  }

  void _startReconnectLoop() {
    _reconnectTimer?.cancel();
    if (_device == null) return;

    _reconnectTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) async {
        final d = _device;
        if (d == null) return;
        try {
          final st = await d.connectionState.first;
          if (st != BluetoothConnectionState.connected) {
            log('Trying auto reconnect...');
            await _tryConnect();
          }
        } catch (e) {
          log('Auto reconnect error: $e');
        }
      },
    );
  }

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    await _connSub?.cancel();
    return super.close();
  }
}
