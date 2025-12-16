import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_ui/pages/widgets/mode_card.dart';
import 'package:flutter_ui/pages/widgets/color_wheel_dialog.dart';
import 'package:flutter_ui/pages/widgets/turn_alarm_effects.dart';
import 'package:flutter_ui/pages/widgets/power_on_effect.dart';

import 'package:flutter_ui/data/mode_preset.dart';
import 'package:flutter_ui/data/modes_repository.dart';

import 'package:flutter_ui/features/device/bloc/device_bloc.dart';

enum PowerOnModeType { tripleBlink, fillRing, fadeIn }

class PowerOnModeConfig {
  final PowerOnModeType type;
  final String title;
  final Color color;

  const PowerOnModeConfig({
    required this.type,
    required this.title,
    required this.color,
  });

  PowerOnModeConfig copyWith({Color? color}) =>
      PowerOnModeConfig(type: type, title: title, color: color ?? this.color);
}

class PowerOnModesTab extends StatefulWidget {
  const PowerOnModesTab({super.key});

  @override
  State<PowerOnModesTab> createState() => _PowerOnModesTabState();
}

class _PowerOnModesTabState extends State<PowerOnModesTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentIndex = 0;

  final List<PowerOnModeConfig> _modes = [
    PowerOnModeConfig(
      type: PowerOnModeType.tripleBlink,
      title: 'Triple blink',
      color: Colors.orange,
    ),
    PowerOnModeConfig(
      type: PowerOnModeType.fillRing,
      title: 'Fill ring',
      color: Colors.orange,
    ),
    PowerOnModeConfig(
      type: PowerOnModeType.fadeIn,
      title: 'Fade in',
      color: Colors.orange,
    ),
  ];

  PowerOnModeConfig get _activeMode => _modes[_currentIndex];

  static const int _defaultSpeed = 128;
  static const int _defaultBrightness = 255;

  int _effectIdFor(PowerOnModeType t) {
    switch (t) {
      case PowerOnModeType.tripleBlink:
        return 0;
      case PowerOnModeType.fillRing:
        return 1;
      case PowerOnModeType.fadeIn:
        return 2;
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _effectIdForIndex(int index) => index.clamp(0, 2);
  String _presetIdForMode(PowerOnModeConfig m) => 'poweron:${m.type.name}';

  Future<void> _pickColor(int index) async {
    final res = await showColorWheelDialog(context, _modes[index].color);
    if (res == null) return;
    setState(() => _modes[index] = _modes[index].copyWith(color: res));
  }

  Future<void> _onSet(int index) async {
    final m = _modes[index];
    final presetId = _presetIdForMode(m);
    final effectId = _effectIdForIndex(index);

    final preset = ModePreset(
      id: presetId,
      category: PresetCategory.powerOn,
      title: m.title,
      type: m
          .type
          .name, // якщо ти вже додав type у ModePreset; якщо ні — прибери цей рядок
      effectId: effectId,
      speed: _defaultSpeed,
      brightness: _defaultBrightness,
      color: m.color, // ✅ ВАЖЛИВО
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
      isFavorite: ModesRepository.isFavorite(presetId),
    );

    await ModesRepository.setCurrent(preset);

    final bloc = context.read<DeviceBloc>();
    bloc.add(
      SavePowerOnPreset(
        DevicePreset(
          effectId: effectId,
          speed: _defaultSpeed,
          brightness: _defaultBrightness,
          r: m.color.red,
          g: m.color.green,
          b: m.color.blue,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _onFavorite(int index) async {
    final m = _modes[index];
    await ModesRepository.toggleFavorite(_presetIdForMode(m));
    if (mounted) setState(() {});
  }

  Widget _carEffect(PowerOnModeConfig mode, double tSec, double p01) {
    switch (mode.type) {
      case PowerOnModeType.tripleBlink:
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
            color: mode.color,
            brightness: 1.0,
            leftEnabled: true,
            rightEnabled: true,
            layout: HeadlightLayout.carSvg,
          ),
        );

      case PowerOnModeType.fillRing:
        final local = (tSec % 3.0);
        final fill01 = (local / 2.0).clamp(0.0, 1.0);
        final b = local < 2.0 ? 1.0 : 0.35;
        return CustomPaint(
          painter: FillRingPainter(
            color: mode.color,
            progress01: fill01,
            brightness: b,
            leftEnabled: true,
            rightEnabled: true,
            layout: HeadlightLayout.carSvg,
          ),
        );

      case PowerOnModeType.fadeIn:
        final local = (tSec % 3.0);
        final fade01 = (local / 2.0).clamp(0.0, 1.0);
        return FadeInLayer(
          progress01: fade01,
          color: mode.color,
          leftEnabled: true,
          rightEnabled: true,
          layout: HeadlightLayout.carSvg,
        );
    }
  }

  Widget _previewEffect(PowerOnModeConfig mode, double tSec, double p01) {
    const previewLayout = HeadlightLayout.singlePreview;

    switch (mode.type) {
      case PowerOnModeType.tripleBlink:
        final on = tripleBlinkOn(
          tSec,
          periodSec: 0.6,
          duty: 0.5,
          blinks: 3,
          gapSec: 1.0,
        );
        return SizedBox(
          width: 190,
          height: 190,
          child: CustomPaint(
            painter: BlinkHeadlightsPainter(
              isOn: on,
              color: mode.color,
              brightness: 1.0,
              leftEnabled: true,
              rightEnabled: false,
              layout: previewLayout,
            ),
          ),
        );

      case PowerOnModeType.fillRing:
        final local = (tSec % 3.0);
        final fill01 = (local / 2.0).clamp(0.0, 1.0);
        final b = local < 2.0 ? 1.0 : 0.35;
        return SizedBox(
          width: 190,
          height: 190,
          child: CustomPaint(
            painter: FillRingPainter(
              color: mode.color,
              progress01: fill01,
              brightness: b,
              leftEnabled: true,
              rightEnabled: false,
              layout: previewLayout,
            ),
          ),
        );

      case PowerOnModeType.fadeIn:
        final local = (tSec % 3.0);
        final fade01 = (local / 2.0).clamp(0.0, 1.0);
        return SizedBox(
          width: 190,
          height: 190,
          child: FadeInLayer(
            progress01: fade01,
            color: mode.color,
            leftEnabled: true,
            rightEnabled: false,
            layout: previewLayout,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final mode = _activeMode;
        final tSec =
            (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;
        final p01 = _controller.value;

        return Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Power-on modes',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

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
                        Positioned.fill(child: _carEffect(mode, tSec, p01)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              height: 360,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.82),
                itemCount: _modes.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, index) {
                  final m = _modes[index];
                  final presetId = _presetIdForMode(m);

                  final fav = ModesRepository.isFavorite(presetId);
                  final current = ModesRepository.loadCurrent(
                    PresetCategory.powerOn,
                  );
                  final isSetSelected = current?.id == presetId;

                  return ModeCard(
                    title: m.title,
                    isActive: index == _currentIndex,
                    preview: _previewEffect(m, tSec, p01),
                    showControls: true,
                    color: m.color,
                    onColorTap: () => _pickColor(index),
                    isFavorite: fav,
                    isSetSelected: isSetSelected,
                    onSet: () => _onSet(index),
                    onFavorite: () => _onFavorite(index),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
