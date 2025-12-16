import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'pages/shell_page.dart';
import 'data/headlight_repository.dart';
import 'data/device_repository.dart';
import 'data/modes_repository.dart';
import 'ble/app_ble_manager.dart';
import 'ble/ble_device_store.dart';
import 'features/device/bloc/device_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await HeadlightRepository.init();
  await DeviceRepository.init();
  await ModesRepository.init();

  AppBleManager.I.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // MUST match ESP32
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String ledCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _GlobalDeviceBlocHost(
        serviceUuid: serviceUuid,
        characteristicUuid: ledCharUuid,
        child: const ShellPage(),
      ),
    );
  }
}

/// Глобальний хост: слухає активний BLE device і тримає один DeviceBloc для всього додатку.
class _GlobalDeviceBlocHost extends StatefulWidget {
  const _GlobalDeviceBlocHost({
    required this.child,
    required this.serviceUuid,
    required this.characteristicUuid,
  });

  final Widget child;
  final String serviceUuid;
  final String characteristicUuid;

  @override
  State<_GlobalDeviceBlocHost> createState() => _GlobalDeviceBlocHostState();
}

class _GlobalDeviceBlocHostState extends State<_GlobalDeviceBlocHost> {
  DeviceBloc? _bloc;
  BluetoothDevice? _currentDevice;

  @override
  void initState() {
    super.initState();
    BleDeviceStore.I.device.addListener(_onDeviceChanged);
    _onDeviceChanged();
  }

  void _onDeviceChanged() {
    final d = BleDeviceStore.I.device.value;
    if (_currentDevice?.remoteId.str == d?.remoteId.str) return;

    // device змінився -> прибиваємо старий bloc, створюємо новий
    _bloc?.close();
    _bloc = null;
    _currentDevice = d;

    if (d != null) {
      _bloc = DeviceBloc(
        device: d,
        serviceUuid: widget.serviceUuid,
        characteristicUuid: widget.characteristicUuid,
      );
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    BleDeviceStore.I.device.removeListener(_onDeviceChanged);
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = _bloc;
    if (bloc == null) return widget.child;

    return BlocProvider<DeviceBloc>.value(value: bloc, child: widget.child);
  }
}
