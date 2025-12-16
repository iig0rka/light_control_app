import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

part 'devices_event.dart';
part 'devices_state.dart';

class DevicesBloc extends Bloc<DevicesEvent, DevicesState> {
  DevicesBloc() : super(DevicesInitial()) {
    on<LoadDevices>(_load);
    on<_SetLoadedDevices>(_setLoadedDevices);
  }

  Future<void> _load(
    LoadDevices event,
    Emitter<DevicesState> emit,
  ) async {
    try {
      emit(DevicesLoading());

      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        throw Exception('Bluetooth not supported by this device');
      }

      final bleState = await FlutterBluePlus.adapterState.first;
      if (bleState != BluetoothAdapterState.on) {
        throw Exception('Bluetooth off');
      }

      // Якщо вже скануємо – зупиняємо попередній скан
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _devicesSub?.cancel();
      _devicesSub = FlutterBluePlus.onScanResults.listen(
        (results) {
          final devices = results.map((e) => e.device).toList();
          add(_SetLoadedDevices(devices));
        },
      );

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
    } catch (e, st) {
      emit(DevicesFailure(exception: e));
      log('$e\n$st');
    }
  }

  Future<void> _setLoadedDevices(
    _SetLoadedDevices event,
    Emitter<DevicesState> emit,
  ) async {
    emit(DevicesLoaded(devices: event.devices));
  }

  StreamSubscription<List<ScanResult>>? _devicesSub;

  @override
  Future<void> close() async {
    await _devicesSub?.cancel();
    return super.close();
  }
}
