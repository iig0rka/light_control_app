import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ble/require_device_bloc.dart';
import '../data/modes_repository.dart';
import '../data/mode_preset.dart';
import '../features/device/bloc/device_bloc.dart';

import 'widgets/mode_card.dart';
import 'widgets/current_lighting_overlay.dart';
import 'widgets/turn_alarm_effects.dart';
import 'widgets/power_on_effect.dart';

class LatestPage extends StatefulWidget {
  const LatestPage({super.key});

  @override
  State<LatestPage> createState() => _LatestPageState();
}

class _LatestPageState extends State<LatestPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  DevicePreset _toDevicePreset(ModePreset p) => DevicePreset(
    effectId: p.effectId,
    speed: p.speed,
    brightness: p.brightness,
    r: p.color.red,
    g: p.color.green,
    b: p.color.blue,
  );

  void _sendPresetToEsp(BuildContext context, ModePreset p) {
    final bloc = context.read<DeviceBloc>();
    final dp = _toDevicePreset(p);

    switch (p.category) {
      case PresetCategory.lighting:
        bloc.add(
          SendDynamicEffect(
            effectId: dp.effectId,
            speed: dp.speed,
            brightness: dp.brightness,
            r: dp.r,
            g: dp.g,
            b: dp.b,
          ),
        );
        break;
      case PresetCategory.powerOn:
        bloc.add(SavePowerOnPreset(dp));
        break;
      case PresetCategory.turn:
        bloc.add(SaveTurnPreset(dp));
        break;
      case PresetCategory.alarm:
        bloc.add(SaveAlarmPreset(dp));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RequireDeviceBloc(
      child: ValueListenableBuilder(
        valueListenable: ModesRepository.listenable(),
        builder: (context, _, __) {
          // ✅ Latest: only lighting
          final items =
              ModesRepository.loadLatest10()
                  .where((p) => p.category == PresetCategory.lighting)
                  .toList()
                ..sort((a, b) => (b.savedAtMs).compareTo(a.savedAtMs));

          if (_index >= items.length) _index = 0;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  final tSec =
                      (_c.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
                  final p01 = _c.value;

                  return Column(
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        'Latest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // -------- CAR PREVIEW --------
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            width: 450,
                            child: AspectRatio(
                              aspectRatio: 1.7,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: SvgPicture.asset(
                                      'assets/svg/car.svg',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  if (items.isNotEmpty)
                                    Positioned.fill(
                                      child: _PresetCarOverlay(
                                        preset: items[_index],
                                        tSec: tSec,
                                        p01: p01,
                                      ),
                                    ),
                                  if (items.isEmpty)
                                    const Positioned.fill(
                                      child: Center(
                                        child: Text(
                                          'No latest lighting presets yet',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // -------- MODE CARDS --------
                      SizedBox(
                        height: 360,
                        child: items.isEmpty
                            ? const SizedBox.shrink()
                            : PageView.builder(
                                controller: PageController(
                                  viewportFraction: 0.82,
                                ),
                                itemCount: items.length,
                                onPageChanged: (i) =>
                                    setState(() => _index = i),
                                itemBuilder: (_, i) {
                                  final p = items[i];
                                  final fav = ModesRepository.isFavorite(p.id);
                                  final current = ModesRepository.loadCurrent(
                                    p.category,
                                  );
                                  final isSetSelected = current?.id == p.id;

                                  return ModeCard(
                                    title: p.title,
                                    isActive: i == _index,
                                    preview: _PresetPreview(
                                      preset: p,
                                      tSec: tSec,
                                      p01: p01,
                                    ),
                                    showControls: false,
                                    isFavorite: fav,
                                    isSetSelected: isSetSelected,
                                    onFavorite: () async {
                                      await ModesRepository.toggleFavorite(
                                        p.id,
                                      );
                                      if (mounted) setState(() {});
                                    },
                                    onSet: () async {
                                      final updated = p.copyWith(
                                        savedAtMs: DateTime.now()
                                            .millisecondsSinceEpoch,
                                        isFavorite: fav,
                                      );
                                      await ModesRepository.setCurrent(updated);
                                      _sendPresetToEsp(context, updated);
                                      if (mounted) setState(() {});
                                    },
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 14),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PresetCarOverlay extends StatelessWidget {
  final ModePreset preset;
  final double tSec;
  final double p01;

  const _PresetCarOverlay({
    required this.preset,
    required this.tSec,
    required this.p01,
  });

  @override
  Widget build(BuildContext context) {
    // Latest тут тільки lighting, але залишаю універсально.
    switch (preset.category) {
      case PresetCategory.lighting:
        // ✅ швидкий універсальний overlay (blink/pulse красиво, інші — як constant glow)
        return CurrentLightingOverlay(preset: preset, enabled: true);

      case PresetCategory.turn:
      case PresetCategory.alarm:
        // для safety: orange як у твоїх таб-ах
        const orange = Color(0xFFFF7800);
        final effectId = preset.effectId;
        if (effectId == 1) {
          return CustomPaint(
            painter: CircleHeadlightPainter(
              progress: p01,
              leftColor: orange,
              rightColor: orange,
              leftBrightness: 1.0,
              rightBrightness: 1.0,
              leftEnabled: true,
              rightEnabled: true,
              layout: HeadlightLayout.carSvg,
            ),
          );
        }
        if (effectId == 2) {
          final on = (tSec % 0.5) < 0.25;
          return CustomPaint(
            painter: BlinkHeadlightsPainter(
              isOn: on,
              color: orange,
              brightness: 1.0,
              leftEnabled: true,
              rightEnabled: true,
              layout: HeadlightLayout.carSvg,
            ),
          );
        }
        return PulsationLayer(
          phase: p01,
          color: orange,
          maxBrightness: 1.0,
          leftEnabled: true,
          rightEnabled: true,
          layout: HeadlightLayout.carSvg,
        );

      case PresetCategory.powerOn:
        // UI-preview power-on
        final type = preset.effectId.clamp(0, 2);
        if (type == 0) {
          final on = tripleBlinkOn(
            tSec,
            periodSec: 0.6,
            duty: 0.5,
            blinks: 3,
            gapSec: 1.0,
          );
          return CustomPaint(
            painter: BlinkHeadlightsPainter(
              isOn: on,
              color: preset.color,
              brightness: 1.0,
              leftEnabled: true,
              rightEnabled: true,
              layout: HeadlightLayout.carSvg,
            ),
          );
        }
        if (type == 1) {
          final local = (tSec % 3.0);
          final fill01 = (local / 2.0).clamp(0.0, 1.0);
          final b = local < 2.0 ? 1.0 : 0.35;
          return CustomPaint(
            painter: FillRingPainter(
              color: preset.color,
              progress01: fill01,
              brightness: b,
              leftEnabled: true,
              rightEnabled: true,
              layout: HeadlightLayout.carSvg,
            ),
          );
        }
        final local = (tSec % 3.0);
        final fade01 = (local / 2.0).clamp(0.0, 1.0);
        return FadeInLayer(
          progress01: fade01,
          color: preset.color,
          leftEnabled: true,
          rightEnabled: true,
          layout: HeadlightLayout.carSvg,
        );
    }
  }
}

class _PresetPreview extends StatelessWidget {
  final ModePreset preset;
  final double tSec;
  final double p01;

  const _PresetPreview({
    required this.preset,
    required this.tSec,
    required this.p01,
  });

  @override
  Widget build(BuildContext context) {
    // Для Latest: простий preview, щоб card була “як у категоріях”
    // lighting — просто крапка/глоу в центрі
    if (preset.category == PresetCategory.lighting) {
      return SizedBox(
        width: 190,
        height: 190,
        child: Center(
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: preset.color.withOpacity(0.20),
              boxShadow: [
                BoxShadow(
                  blurRadius: 30,
                  spreadRadius: 4,
                  color: preset.color.withOpacity(0.55),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // інші — можна підключати твої painters, але тут Latest тільки lighting
    return const SizedBox.shrink();
  }
}
