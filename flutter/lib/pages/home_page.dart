import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/headlight_repository.dart';
import '../data/headlight_state.dart';
import '../data/modes_repository.dart';
import '../data/mode_preset.dart';

import 'package:flutter_ui/features/device/bloc/device_bloc.dart';
import 'quick_drive_page.dart';
import 'widgets/headlight_glow.dart';
import 'widgets/current_lighting_overlay.dart';
import '../ble/require_device_bloc.dart';
import '../ble/ble_device_store.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleMenu;
  final bool isMenuOpen;
  const HomeScreen({
    super.key,
    required this.toggleMenu,
    required this.isMenuOpen,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Color _applyBrightness(Color base, double brightness, bool enabled) {
    final value = enabled ? brightness : 0.0;
    final hsv = HSVColor.fromColor(base);
    return hsv.withValue(value.clamp(0.0, 1.0)).toColor();
  }

  int _b01to255(double v) => (v.clamp(0.0, 1.0) * 255).round().clamp(0, 255);

  DeviceBloc? _tryBloc() {
    try {
      return context.read<DeviceBloc>();
    } catch (_) {
      return null;
    }
  }

  ModePreset? _currentLightingPreset() {
    final p = ModesRepository.loadCurrent(PresetCategory.lighting);
    if (p == null || p.category != PresetCategory.lighting) return null;
    return p;
  }

  void _sendActiveToEsp({
    required HeadlightState stateBeforeToggle,
    required bool enabledAfterToggle,
  }) {
    final bloc = _tryBloc();
    if (bloc == null) return;

    final lighting = _currentLightingPreset();

    // ✅ якщо активний lighting — шлемо 0x02 (динаміка)
    if (stateBeforeToggle.activeSource == ActiveModeSource.lighting &&
        lighting != null) {
      bloc.add(
        SendDynamicEffect(
          effectId: lighting.effectId,
          speed: lighting.speed,
          brightness: enabledAfterToggle ? lighting.brightness : 0,
          r: lighting.color.red,
          g: lighting.color.green,
          b: lighting.color.blue,
        ),
      );
      return;
    }

    // ✅ інакше quick 0x01 (L/R)
    final leftB = enabledAfterToggle ? stateBeforeToggle.leftBrightness : 0.0;
    final rightB = enabledAfterToggle ? stateBeforeToggle.rightBrightness : 0.0;

    bloc.add(
      SendQuickDriveColor(
        side: BleSide.left,
        r: stateBeforeToggle.leftColor.red,
        g: stateBeforeToggle.leftColor.green,
        b: stateBeforeToggle.leftColor.blue,
        brightness: _b01to255(leftB),
      ),
    );

    bloc.add(
      SendQuickDriveColor(
        side: BleSide.right,
        r: stateBeforeToggle.rightColor.red,
        g: stateBeforeToggle.rightColor.green,
        b: stateBeforeToggle.rightColor.blue,
        brightness: _b01to255(rightB),
      ),
    );
  }

  Future<void> _toggleMasterLights(bool currentEnabled) async {
    // беремо стан ДО зміни (там лежить “правильна” brightness)
    final prev = HeadlightRepository.load();

    final nextEnabled = !currentEnabled;
    await HeadlightRepository.setLightsEnabled(nextEnabled);

    // 🔥 слемо саме те, що зараз активне (quick або lighting)
    _sendActiveToEsp(stateBeforeToggle: prev, enabledAfterToggle: nextEnabled);
  }

  Future<void> _openQuickDrive(BuildContext context, HeadlightSide side) async {
    final ok =
        BleDeviceStore.I.device.value != null &&
        BleDeviceStore.I.isConnected.value == true;

    if (!ok) {
      Navigator.pushNamed(context, '/connect');
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RequireDeviceBloc(child: QuickDriveScreen(initialSide: side)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box>(
      valueListenable: HeadlightRepository.listenable(),
      builder: (context, box, _) {
        final state = HeadlightRepository.load();

        final leftColor = state.leftColor;
        final rightColor = state.rightColor;
        final leftBrightness = state.leftBrightness;
        final rightBrightness = state.rightBrightness;
        final lightsEnabled = state.lightsEnabled;

        final lightingPreset = _currentLightingPreset();

        final showLighting =
            lightsEnabled &&
            state.activeSource == ActiveModeSource.lighting &&
            lightingPreset != null;

        final screen = MediaQuery.of(context).size;
        final carHeight = screen.height * 0.32;

        return Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              right: 20,
              child: widget.isMenuOpen
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: widget.toggleMenu,
                    ),
            ),

            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: carHeight,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: BleDeviceStore.I.isConnected,
                      builder: (context, connected, _) {
                        final ok =
                            connected && BleDeviceStore.I.device.value != null;

                        return Opacity(
                          opacity: ok ? 1.0 : 0.35,
                          child: LayoutBuilder(
                            builder: (context, carConstraints) {
                              final cw = carConstraints.maxWidth;
                              final ch = carConstraints.maxHeight;

                              final leftRect = Rect.fromLTWH(
                                cw * 0.13,
                                ch * 0.39,
                                cw * 0.18,
                                ch * 0.18,
                              );

                              final rightRect = Rect.fromLTWH(
                                cw * (1 - 0.12 - 0.18),
                                ch * 0.39,
                                cw * 0.18,
                                ch * 0.18,
                              );

                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: ok
                                          ? null
                                          : () => Navigator.pushNamed(
                                              context,
                                              '/connect',
                                            ),
                                      child: SvgPicture.asset(
                                        'assets/svg/car.svg',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                  if (!ok)
                                    const Positioned.fill(
                                      child: Center(
                                        child: Text(
                                          'NO DEVICE CONNECTED',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),

                                  if (showLighting && ok)
                                    Positioned.fill(
                                      child: CurrentLightingOverlay(
                                        preset: lightingPreset!,
                                        enabled: lightsEnabled,
                                      ),
                                    )
                                  else ...[
                                    HeadlightGlow(
                                      rect: leftRect,
                                      color: _applyBrightness(
                                        leftColor,
                                        leftBrightness,
                                        lightsEnabled && ok,
                                      ),
                                      isActive: ok,
                                      brightness: (lightsEnabled && ok)
                                          ? leftBrightness
                                          : 0.0,
                                    ),
                                    HeadlightGlow(
                                      rect: rightRect,
                                      color: _applyBrightness(
                                        rightColor,
                                        rightBrightness,
                                        lightsEnabled && ok,
                                      ),
                                      isActive: ok,
                                      brightness: (lightsEnabled && ok)
                                          ? rightBrightness
                                          : 0.0,
                                    ),
                                  ],

                                  Positioned.fromRect(
                                    rect: leftRect,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () {
                                        if (!ok) {
                                          Navigator.pushNamed(
                                            context,
                                            '/connect',
                                          );
                                          return;
                                        }
                                        _openQuickDrive(
                                          context,
                                          HeadlightSide.left,
                                        );
                                      },
                                    ),
                                  ),

                                  Positioned.fromRect(
                                    rect: rightRect,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () {
                                        if (!ok) {
                                          Navigator.pushNamed(
                                            context,
                                            '/connect',
                                          );
                                          return;
                                        }
                                        _openQuickDrive(
                                          context,
                                          HeadlightSide.right,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 25),

                  ValueListenableBuilder<bool>(
                    valueListenable: BleDeviceStore.I.isConnected,
                    builder: (_, connected, __) {
                      final ok =
                          connected && BleDeviceStore.I.device.value != null;

                      return GestureDetector(
                        onTap: ok
                            ? () => _toggleMasterLights(lightsEnabled)
                            : () => Navigator.pushNamed(context, '/connect'),
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (lightsEnabled && ok)
                                ? Colors.white.withOpacity(0.18)
                                : Colors.white.withOpacity(0.08),
                            border: Border.all(
                              color: ok
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.white24,
                              width: 1.6,
                            ),
                          ),
                          child: Icon(
                            lightsEnabled && ok
                                ? Icons.lightbulb
                                : Icons.lightbulb_outline,
                            color: ok
                                ? (lightsEnabled
                                      ? Colors.yellowAccent
                                      : Colors.white70)
                                : Colors.white38,
                            size: 36,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
