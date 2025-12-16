// lib/pages/connect_device_page.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../data/device.dart';
import '../data/device_repository.dart';
import '../ble/ble_device_store.dart';

import 'widgets/device_card.dart';
import 'widgets/device_swipe_title.dart';
import 'widgets/edit_device_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble/app_ble_manager.dart';

class ConnectDevicePage extends StatefulWidget {
  const ConnectDevicePage({super.key});

  @override
  State<ConnectDevicePage> createState() => _ConnectDevicePageState();
}

class _ConnectDevicePageState extends State<ConnectDevicePage> {
  String? _openedId;

  bool _isScanning = false;
  StreamSubscription<List<ScanResult>>? _scanSub;
  final Map<String, ScanResult> _scanMap = {};

  List<ScanResult> get _scanResults =>
      _scanMap.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  // MUST match ESP32
  static const String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";

  // AUTH channel (твій логін/пароль)
  static const String authCharUuid = "c0de0001-1fb5-459e-8fcc-c5c9c331914b";
  //static const String passCharUuid = "c0de0002-1fb5-459e-8fcc-c5c9c331914b";
  Future<void> ensureBlePermissions() async {
    // Android 12+: Nearby devices
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();

    // На багатьох девайсах без Location все одно 0 результатів
    await Permission.locationWhenInUse.request();
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    await ensureBlePermissions();

    setState(() {
      _isScanning = true;
      _scanMap.clear();
    });

    await _scanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      debugPrint('[SCAN] batch size: ${results.length}');
      for (final r in results) {
        final name = r.device.advName.isNotEmpty
            ? r.device.advName
            : r.device.platformName;

        debugPrint(
          '[SCAN] ${r.device.remoteId.str} name="$name" rssi=${r.rssi}',
        );

        // тимчасово НЕ фільтруй взагалі, щоб побачити хоч щось
        _scanMap[r.device.remoteId.str] = r;
      }
      if (mounted) setState(() {});
    });

    try {
      debugPrint('[SCAN] startScan...');
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidScanMode: AndroidScanMode.lowLatency,
      );
      debugPrint('[SCAN] done');
    } catch (e) {
      debugPrint('[SCAN] error: $e');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint('>>> ConnectDevicePage OPENED');
  }

  Future<String?> _askPassword(BuildContext context) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter device password'),
        content: TextField(
          controller: c,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<BluetoothCharacteristic?> _findChar(
    BluetoothDevice device,
    String svcUuid,
    String chrUuid,
  ) async {
    final services = await device.discoverServices();

    BluetoothService? svc;
    for (final s in services) {
      if (s.uuid.toString().toLowerCase() == svcUuid.toLowerCase()) {
        svc = s;
        break;
      }
    }
    if (svc == null) return null;

    for (final c in svc.characteristics) {
      if (c.uuid.toString().toLowerCase() == chrUuid.toLowerCase()) {
        return c;
      }
    }
    return null;
  }

  String _deviceTitle(BluetoothDevice device) {
    final name = device.advName.isNotEmpty
        ? device.advName
        : device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;
    return name;
  }

  Future<void> _connectBleDevice(ScanResult r) async {
    final device = r.device;

    final password = await _askPassword(context);
    if (password == null || password.isEmpty) return;

    final name = _deviceTitle(device);

    try {
      final st = await device.connectionState.first;
      if (st != BluetoothConnectionState.connected) {
        await device.connect(timeout: const Duration(seconds: 12));
      }

      // AUTH
      final authChar = await _findChar(device, serviceUuid, authCharUuid);
      if (authChar == null) {
        throw Exception('Auth characteristic not found (UUID mismatch)');
      }

      await authChar.write(password.codeUnits, withoutResponse: false);

      // читаємо відповідь (ESP ставить "OK" або "BAD")
      List<int> resp = [];
      try {
        resp = await authChar.read();
      } catch (_) {
        // інколи read може не дати одразу, але для тебе ок
      }

      final respStr = String.fromCharCodes(resp).trim();

      if (respStr != 'OK') {
        try {
          await device.disconnect();
        } catch (_) {}
        throw Exception(respStr.isEmpty ? 'BAD' : respStr);
      }

      // ✅ OK → записуємо в Hive як connected
      await DeviceRepository.upsert(
        Device(
          id: device.remoteId.str,
          title: name,
          name: name,
          password: password,
          isConnected: true,
        ),
      );
      AppBleManager.I.setLastConnected(
        deviceId: device.remoteId.str,
        password: password,
      );
      // ✅ ГОЛОВНЕ: робимо цей девайс активним для всіх екранів (Quick/Categories/etc)
      BleDeviceStore.I.setDevice(device);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connected to $name')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
    }
  }

  Future<void> _disconnectById(String deviceId) async {
    try {
      final d = BluetoothDevice.fromId(deviceId);
      await d.disconnect();
    } catch (_) {
      // ignore (може вже відключений)
    }
  }

  Future<void> _writePasswordToDevice({
    required BluetoothDevice device,
    required String password,
  }) async {
    final services = await device.discoverServices();

    final svc = services.firstWhere(
      (s) => s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase(),
    );

    final chr = svc.characteristics.firstWhere(
      (c) => c.uuid.toString().toLowerCase() == authCharUuid.toLowerCase(),
    );

    await chr.write(password.codeUnits, withoutResponse: false);
  }

  /// Натиснули на connected девайс -> зробити його активним для керування
  Future<void> _activateConnected(Device d) async {
    try {
      final ble = BluetoothDevice.fromId(d.id);

      final st = await ble.connectionState.first;
      if (st != BluetoothConnectionState.connected) {
        await ble.connect(timeout: const Duration(seconds: 10));
      }

      // Якщо треба — можна тут повторно підтвердити пароль (але ти вже робив OK при підключенні)
      BleDeviceStore.I.setDevice(ble);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Active device: ${d.title}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to activate: $e')));
    }
  }

  Future<void> _editDevice(Device d) async {
    final res = await showEditDeviceDialog(
      context: context,
      initialTitle: d.title,
      initialPassword: d.password,
    );
    if (res == null) return;

    // 1) зберегти в Hive
    final updated = Device(
      id: d.id,
      title: res.title,
      name: d.name,
      password: res.password,
      isConnected: d.isConnected,
    );
    await DeviceRepository.upsert(updated);

    // 2) якщо підключений — одразу пушимо новий пароль на плату
    if (updated.isConnected) {
      try {
        final ble = BluetoothDevice.fromId(updated.id);

        final st = await ble.connectionState.first;
        if (st != BluetoothConnectionState.connected) {
          await ble.connect(timeout: const Duration(seconds: 10));
        }

        await _writePasswordToDevice(device: ble, password: updated.password);

        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Device updated')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved, but failed to send password: $e')),
        );
      }
    }
  }

  Future<void> _deleteDevice(Device d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete device?'),
        content: Text('Delete "${d.title}" and disconnect?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // 1) disconnect
    if (d.isConnected) {
      await _disconnectById(d.id);
    }

    // 1.1) якщо це був активний девайс — чистимо store
    final active = BleDeviceStore.I.device.value;
    if (active != null && active.remoteId.str == d.id) {
      BleDeviceStore.I.clear();
    }

    // 2) remove from Hive
    await DeviceRepository.delete(d.id);

    if (_openedId == d.id) {
      setState(() => _openedId = null);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Device deleted')));
  }

  // UI
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(context),
              const SizedBox(height: 16),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: DeviceRepository.listenable(),
                  builder: (context, box, _) {
                    final all = DeviceRepository.loadAll();

                    // ✅ Connected = тільки те, що реально збереглось після OK
                    final connected = all.where((d) => d.isConnected).toList();
                    final connectedIds = connected.map((d) => d.id).toSet();
                    final visibleScanResults = _scanResults
                        .where(
                          (r) => !connectedIds.contains(r.device.remoteId.str),
                        )
                        .toList();

                    final active = BleDeviceStore.I.device.value;
                    final activeId = active?.remoteId.str;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Connected',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (connected.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: _NoDevicesCard(text: 'No devices'),
                            )
                          else
                            ...connected.map(
                              (d) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 6,
                                ),
                                child: GestureDetector(
                                  onTap: () => _activateConnected(d),
                                  child: Stack(
                                    children: [
                                      DeviceSwipeTile(
                                        deviceName: d.title,
                                        isOpen: _openedId == d.id,
                                        onOpen: () =>
                                            setState(() => _openedId = d.id),
                                        onClose: () {
                                          if (_openedId == d.id)
                                            setState(() => _openedId = null);
                                        },
                                        onEdit: () => _editDevice(d),
                                        onDelete: () => _deleteDevice(d),
                                        badge: (activeId == d.id)
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withOpacity(0.35),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'ACTIVE',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      if (activeId == d.id)
                                        Positioned(
                                          right: 12,
                                          top: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.18,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.35,
                                                ),
                                              ),
                                            ),
                                            child: const Text(
                                              'ACTIVE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 32),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Found devices',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (visibleScanResults.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: _NoDevicesCard(text: 'No devices'),
                            )
                          else
                            ...visibleScanResults.map((r) {
                              final d = r.device;
                              final name = _deviceTitle(d);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 6,
                                ),
                                child: GestureDetector(
                                  onTap: () => _connectBleDevice(r),
                                  child: DeviceCard(title: name),
                                ),
                              );
                            }),

                          const SizedBox(height: 40),
                          Center(child: _buildResearchButton()),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(top: 8, bottom: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Text(
            'Connect device',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResearchButton() {
    return GestureDetector(
      onTap: _isScanning ? null : _startScan,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 200,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF4C6FEA), Color(0xFF3B3BAA)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _isScanning ? 'Scanning...' : 'Research',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoDevicesCard extends StatelessWidget {
  final String text;
  const _NoDevicesCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.08),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 15),
      ),
    );
  }
}
