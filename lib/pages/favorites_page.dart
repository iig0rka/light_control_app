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

class FavouritesPage extends StatefulWidget {
  const FavouritesPage({super.key});

  @override
  State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage>
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
          final items = ModesRepository.loadFavorites();
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
                        'Favourites',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),

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
                                      child: _FavCarOverlay(
                                        preset: items[_index],
                                        tSec: tSec,
                                        p01: p01,
                                      ),
                                    ),
                                  if (items.isEmpty)
                                    const Positioned.fill(
                                      child: Center(
                                        child: Text(
                                          'No favourites yet',
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
                                  final current = ModesRepository.loadCurrent(
                                    p.category,
                                  );
                                  final isSetSelected = current?.id == p.id;

                                  return ModeCard(
                                    title: p.title,
                                    isActive: i == _index,
                                    preview: _FavPreview(
                                      preset: p,
                                      tSec: tSec,
                                      p01: p01,
                                    ),
                                    showControls: false,
                                    isFavorite: true,
                                    isSetSelected: isSetSelected,
                                    onFavorite: () async {
                                      await ModesRepository.toggleFavorite(
                                        p.id,
                                      );
                                      if (mounted) setState(() {});
                                    },
                                    onSet: () async {
                                      // ✅ один активний на категорію забезпечує setCurrent(category)
                                      final updated = p.copyWith(
                                        savedAtMs: DateTime.now()
                                            .millisecondsSinceEpoch,
                                        isFavorite: true,
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

class _FavCarOverlay extends StatelessWidget {
  final ModePreset preset;
  final double tSec;
  final double p01;

  const _FavCarOverlay({
    required this.preset,
    required this.tSec,
    required this.p01,
  });

  @override
  Widget build(BuildContext context) {
    switch (preset.category) {
      case PresetCategory.lighting:
        return CurrentLightingOverlay(preset: preset, enabled: true);

      case PresetCategory.turn:
        // turn preview: left then right (як ти хотів), але тут простіше: обидві
        const orange = Color(0xFFFF7800);
        return _TurnAlarmPainter(
          effectId: preset.effectId,
          tSec: tSec,
          p01: p01,
          color: orange,
        );

      case PresetCategory.alarm:
        const orange = Color(0xFFFF7800);
        return _TurnAlarmPainter(
          effectId: preset.effectId,
          tSec: tSec,
          p01: p01,
          color: orange,
        );

      case PresetCategory.powerOn:
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

class _TurnAlarmPainter extends StatelessWidget {
  final int effectId;
  final double tSec;
  final double p01;
  final Color color;

  const _TurnAlarmPainter({
    required this.effectId,
    required this.tSec,
    required this.p01,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (effectId == 1) {
      return CustomPaint(
        painter: CircleHeadlightPainter(
          progress: p01,
          leftColor: color,
          rightColor: color,
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
          color: color,
          brightness: 1.0,
          leftEnabled: true,
          rightEnabled: true,
          layout: HeadlightLayout.carSvg,
        ),
      );
    }
    return PulsationLayer(
      phase: p01,
      color: color,
      maxBrightness: 1.0,
      leftEnabled: true,
      rightEnabled: true,
      layout: HeadlightLayout.carSvg,
    );
  }
}

class _FavPreview extends StatelessWidget {
  final ModePreset preset;
  final double tSec;
  final double p01;

  const _FavPreview({
    required this.preset,
    required this.tSec,
    required this.p01,
  });

  @override
  Widget build(BuildContext context) {
    const previewLayout = HeadlightLayout.singlePreview;

    if (preset.category == PresetCategory.turn ||
        preset.category == PresetCategory.alarm) {
      const orange = Color(0xFFFF7800);
      if (preset.effectId == 1) {
        return SizedBox(
          width: 190,
          height: 190,
          child: CustomPaint(
            painter: CircleHeadlightPainter(
              progress: p01,
              leftColor: orange,
              rightColor: orange,
              leftBrightness: 1.0,
              rightBrightness: 1.0,
              leftEnabled: true,
              rightEnabled: false,
              layout: previewLayout,
            ),
          ),
        );
      }
      if (preset.effectId == 2) {
        final on = (tSec % 0.5) < 0.25;
        return SizedBox(
          width: 190,
          height: 190,
          child: CustomPaint(
            painter: BlinkHeadlightsPainter(
              isOn: on,
              color: orange,
              brightness: 1.0,
              leftEnabled: true,
              rightEnabled: false,
              layout: previewLayout,
            ),
          ),
        );
      }
      return SizedBox(
        width: 190,
        height: 190,
        child: PulsationLayer(
          phase: p01,
          color: orange,
          maxBrightness: 1.0,
          leftEnabled: true,
          rightEnabled: false,
          layout: previewLayout,
        ),
      );
    }

    // lighting/powerOn — легкий preview
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
}
