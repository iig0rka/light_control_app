part of 'device_bloc.dart';

class DeviceState extends Equatable {
  const DeviceState({
    this.isReady = false,
    this.isConnected = false,
    this.lastError,
  });

  final bool isReady;
  final bool isConnected;
  final Object? lastError;

  DeviceState copyWith({bool? isReady, bool? isConnected, Object? lastError}) {
    return DeviceState(
      isReady: isReady ?? this.isReady,
      isConnected: isConnected ?? this.isConnected,
      lastError: lastError,
    );
  }

  @override
  List<Object?> get props => [isReady, isConnected, lastError];
}
