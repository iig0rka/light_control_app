import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../features/device/bloc/device_bloc.dart';
import 'ble_device_store.dart';
import '../pages/connect_device_page.dart';

class RequireDeviceBloc extends StatelessWidget {
  const RequireDeviceBloc({
    super.key,
    required this.child,
    this.serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
    this.characteristicUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8',
    this.fallbackTitle = 'No connected device',
    this.fallbackSubtitle = 'Connect your ESP32 to enable control.',
  });

  final Widget child;
  final String serviceUuid;
  final String characteristicUuid;

  // UI тексти (щоб можна було різне писати на різних екранах)
  final String fallbackTitle;
  final String fallbackSubtitle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BluetoothDevice?>(
      valueListenable: BleDeviceStore.I.device,
      builder: (context, device, _) {
        if (device == null) {
          // ✅ НЕ редіректимо автоматично — показуємо заглушку
          return _NoDeviceScreen(
            title: fallbackTitle,
            subtitle: fallbackSubtitle,
            onConnect: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectDevicePage()),
              );
            },
          );
        }

        return BlocProvider<DeviceBloc>(
          create: (_) => DeviceBloc(
            device: device,
            serviceUuid: serviceUuid,
            characteristicUuid: characteristicUuid,
          ),
          child: child,
        );
      },
    );
  }
}

class RequireDevice extends StatelessWidget {
  const RequireDevice({
    super.key,
    required this.child,
    this.fallbackTitle = 'No connected device',
    this.fallbackSubtitle = 'Connect your ESP32 to enable control.',
  });

  final Widget child;
  final String fallbackTitle;
  final String fallbackSubtitle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BluetoothDevice?>(
      valueListenable: BleDeviceStore.I.device,
      builder: (context, device, _) {
        if (device == null) {
          return _NoDeviceScreen(
            title: fallbackTitle,
            subtitle: fallbackSubtitle,
            onConnect: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectDevicePage()),
              );
            },
          );
        }

        // ✅ ВАЖЛИВО: НЕ створюємо BlocProvider тут
        // бо DeviceBloc у тебе має бути глобальний
        return child;
      },
    );
  }
}

class _NoDeviceScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onConnect;

  const _NoDeviceScreen({
    required this.title,
    required this.subtitle,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF111A3A),
              Color(0xFF145F9F),
              Color(0xFF040A3A),
              Color(0xFF171720),
            ],
            stops: [0, 0.35, 0.74, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.bluetooth_disabled,
                    color: Colors.white70,
                    size: 52,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: onConnect,
                    child: const Text('Open Connect device'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
