import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'device_event.dart';
part 'device_state.dart';

/// Пресет для EEPROM / режимів
class DevicePreset extends Equatable {
  const DevicePreset({
    required this.effectId,
    required this.speed,
    required this.brightness,
    required this.r,
    required this.g,
    required this.b,
  });

  final int effectId; // 0..255
  final int speed; // 0..255
  final int brightness; // 0..255
  final int r; // 0..255
  final int g; // 0..255
  final int b; // 0..255

  @override
  List<Object?> get props => [effectId, speed, brightness, r, g, b];
}

/// BLE команди (байт 0 в пакеті)
class BleCmd {
  static const int quickDriveColor = 0x01; // [cmd, side, r,g,b,brightness]
  static const int setDynamicEffect =
      0x02; // [cmd, effectId, speed, brightness, r,g,b]

  static const int savePowerOn = 0x10; // EEPROM
  static const int saveTurn = 0x11; // EEPROM
  static const int saveAlarm = 0x12; // EEPROM
}

/// Side для QuickDrive
class BleSide {
  static const int both = 0;
  static const int left = 1;
  static const int right = 2;
}

class BlePacket {
  static List<int> quickDriveColor({
    required int side, // 0 both, 1 left, 2 right
    required int r,
    required int g,
    required int b,
    required int brightness,
  }) => [BleCmd.quickDriveColor, side, r, g, b, brightness];

  static List<int> dynamicEffect({
    required int effectId,
    required int speed,
    required int brightness,
    required int r,
    required int g,
    required int b,
  }) => [BleCmd.setDynamicEffect, effectId, speed, brightness, r, g, b];

  static List<int> savePreset(int cmd, DevicePreset p) => [
    cmd,
    p.effectId,
    p.speed,
    p.brightness,
    p.r,
    p.g,
    p.b,
  ];
}

class DeviceBloc extends Bloc<DeviceEvent, DeviceState> {
  DeviceBloc({
    required BluetoothDevice device,
    required this.serviceUuid,
    required this.characteristicUuid,
  }) : _device = device,
       super(const DeviceState()) {
    on<SendQuickDriveColor>(_onQuickDriveColor);
    on<SendDynamicEffect>(_onDynamicEffect);
    on<SavePowerOnPreset>(_onSavePowerOn);
    on<SaveTurnPreset>(_onSaveTurn);
    on<SaveAlarmPreset>(_onSaveAlarm);
    on<ForceReconnect>(_onForceReconnect);

    _deviceSub = _device.connectionState.listen(_onConnState);
    _connectAndInit();
  }

  final String serviceUuid;
  final String characteristicUuid;

  final BluetoothDevice _device;
  BluetoothCharacteristic? _ch;
  StreamSubscription<BluetoothConnectionState>? _deviceSub;

  // throttle тільки для QuickDrive
  static const Duration _quickDriveThrottle = Duration(milliseconds: 100);
  Timer? _quickDriveTimer;

  // ✅ ВАЖЛИВО: окремий pending для лівої і правої, щоб "both" не затирало пакет
  List<int>? _pendingLeft;
  List<int>? _pendingRight;
  bool _isFlushingQuick = false;

  // reconnect guard
  bool _isConnecting = false;
  Timer? _reconnectBackoff;
  int _reconnectAttempt = 0;

  Future<void> _connectAndInit() async {
    if (_isConnecting) return;
    _isConnecting = true;

    try {
      emit(state.copyWith(isReady: false, lastError: null));

      final current = await _device.connectionState.first;
      if (current != BluetoothConnectionState.connected) {
        await _device.connect(
          autoConnect: false,
          timeout: const Duration(seconds: 12),
        );
      }

      await _saveLastDeviceId(_device);

      final services = await _device.discoverServices();
      for (final s in services) {
        log('SVC: ${s.uuid}');
        for (final c in s.characteristics) {
          log('  CHR: ${c.uuid} props=${c.properties}');
        }
      }
      final service = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase(),
        orElse: () => throw StateError('Service not found: $serviceUuid'),
      );

      _ch = service.characteristics.firstWhere(
        (c) =>
            c.uuid.toString().toLowerCase() == characteristicUuid.toLowerCase(),
        orElse: () =>
            throw StateError('Characteristic not found: $characteristicUuid'),
      );

      _reconnectAttempt = 0;
      emit(state.copyWith(isReady: true, isConnected: true, lastError: null));
      log('BLE ready: service=$serviceUuid char=$characteristicUuid');
    } catch (e) {
      log('Connect/init error: $e');
      _ch = null;
      emit(state.copyWith(isReady: false, isConnected: false, lastError: e));
    } finally {
      _isConnecting = false;
    }
  }

  void _onConnState(BluetoothConnectionState s) {
    final connected = (s == BluetoothConnectionState.connected);
    emit(state.copyWith(isConnected: connected));

    if (!connected) {
      _ch = null;
      _scheduleReconnect();
    } else {
      if (!state.isReady) _connectAndInit();
    }
  }

  void _scheduleReconnect() {
    _reconnectBackoff?.cancel();

    _reconnectAttempt = (_reconnectAttempt + 1).clamp(1, 6);
    final delayMs = 250 * (1 << (_reconnectAttempt - 1)); // 250..4000
    final delay = Duration(milliseconds: delayMs.clamp(250, 4000));

    _reconnectBackoff = Timer(delay, () {
      if (!isClosed) _connectAndInit();
    });
  }

  Future<void> _onForceReconnect(
    ForceReconnect e,
    Emitter<DeviceState> emit,
  ) async {
    _reconnectBackoff?.cancel();
    _reconnectAttempt = 0;
    await _connectAndInit();
  }

  Future<void> _saveLastDeviceId(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_id', device.remoteId.str);
    } catch (e) {
      log('Save last_device_id error: $e');
    }
  }

  // --- Handlers ---

  void _onQuickDriveColor(SendQuickDriveColor e, Emitter<DeviceState> emit) {
    final pkt = BlePacket.quickDriveColor(
      side: _clamp8(e.side),
      r: _clamp8(e.r),
      g: _clamp8(e.g),
      b: _clamp8(e.b),
      brightness: _clamp8(e.brightness),
    );

    // ✅ розкладаємо по pending-буферам
    if (e.side == BleSide.left) {
      _pendingLeft = pkt;
    } else if (e.side == BleSide.right) {
      _pendingRight = pkt;
    } else {
      // якщо хтось таки шле side=both — вважаємо що треба застосувати до обох
      _pendingLeft = BlePacket.quickDriveColor(
        side: BleSide.left,
        r: _clamp8(e.r),
        g: _clamp8(e.g),
        b: _clamp8(e.b),
        brightness: _clamp8(e.brightness),
      );
      _pendingRight = BlePacket.quickDriveColor(
        side: BleSide.right,
        r: _clamp8(e.r),
        g: _clamp8(e.g),
        b: _clamp8(e.b),
        brightness: _clamp8(e.brightness),
      );
    }

    // ✅ один таймер на 100мс, але за один flush може піти 1 або 2 пакети
    _quickDriveTimer ??= Timer(_quickDriveThrottle, () async {
      _quickDriveTimer?.cancel();
      _quickDriveTimer = null;
      await _flushQuickDrive();
    });
  }

  Future<void> _flushQuickDrive() async {
    if (_isFlushingQuick) return;
    _isFlushingQuick = true;

    try {
      final left = _pendingLeft;
      final right = _pendingRight;
      _pendingLeft = null;
      _pendingRight = null;

      if (left != null) await _write(left);
      if (right != null) await _write(right);
    } finally {
      _isFlushingQuick = false;
    }
  }

  Future<void> _onDynamicEffect(
    SendDynamicEffect e,
    Emitter<DeviceState> emit,
  ) async {
    final packet = BlePacket.dynamicEffect(
      effectId: _clamp8(e.effectId),
      speed: _clamp8(e.speed),
      brightness: _clamp8(e.brightness),
      r: _clamp8(e.r),
      g: _clamp8(e.g),
      b: _clamp8(e.b),
    );

    await _write(packet);
  }

  Future<void> _onSavePowerOn(
    SavePowerOnPreset e,
    Emitter<DeviceState> emit,
  ) async {
    await _write(BlePacket.savePreset(BleCmd.savePowerOn, e.preset));
  }

  Future<void> _onSaveTurn(SaveTurnPreset e, Emitter<DeviceState> emit) async {
    await _write(BlePacket.savePreset(BleCmd.saveTurn, e.preset));
  }

  Future<void> _onSaveAlarm(
    SaveAlarmPreset e,
    Emitter<DeviceState> emit,
  ) async {
    await _write(BlePacket.savePreset(BleCmd.saveAlarm, e.preset));
  }

  Future<void> _write(List<int> packet) async {
    final ch = _ch;
    if (ch == null || !state.isReady) {
      log('Write skipped: BLE not ready');
      return;
    }
    try {
      await ch.write(packet, allowLongWrite: false);
      log(
        'BLE write: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
    } catch (e) {
      log('Write error: $e');
      emit(state.copyWith(lastError: e));
    }
  }

  int _clamp8(int v) => v.clamp(0, 255);

  @override
  Future<void> close() async {
    _reconnectBackoff?.cancel();
    _quickDriveTimer?.cancel();
    await _deviceSub?.cancel();
    return super.close();
  }
}
