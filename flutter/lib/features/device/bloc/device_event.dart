part of 'device_bloc.dart';

sealed class DeviceEvent extends Equatable {
  const DeviceEvent();
  @override
  List<Object?> get props => [];
}

/// QuickDrive: шлемо r,g,b + brightness (0..255)
final class SendQuickDriveColor extends DeviceEvent {
  const SendQuickDriveColor({
    required this.side, // BleSide.*
    required this.r,
    required this.g,
    required this.b,
    required this.brightness,
  });

  final int side;
  final int r;
  final int g;
  final int b;
  final int brightness;

  @override
  List<Object?> get props => [side, r, g, b, brightness];
}

/// (не обовʼязково для quick-drive, але залишив для інших вкладок)
final class SendDynamicEffect extends DeviceEvent {
  const SendDynamicEffect({
    required this.effectId,
    required this.speed,
    required this.brightness,
    required this.r,
    required this.g,
    required this.b,
  });

  final int effectId;
  final int speed;
  final int brightness;
  final int r;
  final int g;
  final int b;

  @override
  List<Object?> get props => [effectId, speed, brightness, r, g, b];
}

final class SavePowerOnPreset extends DeviceEvent {
  const SavePowerOnPreset(this.preset);
  final DevicePreset preset;

  @override
  List<Object?> get props => [preset];
}

final class SaveTurnPreset extends DeviceEvent {
  const SaveTurnPreset(this.preset);
  final DevicePreset preset;

  @override
  List<Object?> get props => [preset];
}

final class SaveAlarmPreset extends DeviceEvent {
  const SaveAlarmPreset(this.preset);
  final DevicePreset preset;

  @override
  List<Object?> get props => [preset];
}

/// Ручний форс reconnect
final class ForceReconnect extends DeviceEvent {
  const ForceReconnect();
}
