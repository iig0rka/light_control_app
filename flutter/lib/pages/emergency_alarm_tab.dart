import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_ui/pages/widgets/mode_card.dart';
import 'package:flutter_ui/pages/widgets/turn_alarm_effects.dart';

import 'package:flutter_ui/data/mode_preset.dart';
import 'package:flutter_ui/data/modes_repository.dart';

import 'package:flutter_ui/features/device/bloc/device_bloc.dart';

class EmergencyAlarmTab extends StatefulWidget {
  const EmergencyAlarmTab({super.key});

  @override
  State<EmergencyAlarmTab> createState() => _EmergencyAlarmTabState();
}

class _EmergencyAlarmTabState extends State<EmergencyAlarmTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentIndex = 0;

  static const _titles = ['Circle', 'Blink', 'Pulsation'];

  static const Color _fixedOrange = Color(0xFFFF7800);
  static const int _defaultSpeed = 128;
  static const int _defaultBrightness = 255;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _blinkOn(double tSeconds) {
    const blinkPeriod = 0.5;
    const onWindow = 0.25;
    return (tSeconds % blinkPeriod) < onWindow;
  }

  int _effectIdForIndex(int index) {
    // ESP: 1 circle, 2 blink, 3 pulsation
    switch (index) {
      case 0:
        return 1;
      case 1:
        return 2;
      default:
        return 3;
    }
  }

  Future<void> _onSet(int index) async {
    final presetId = 'emergency:$index';

    final preset = ModePreset(
      id: presetId,
      category: PresetCategory.alarm, // ✅ було emergency -> тепер alarm
      title: _titles[index],
      effectId: _effectIdForIndex(index),
      speed: _defaultSpeed,
      brightness: _defaultBrightness,
      color: _fixedOrange,
      savedAtMs: DateTime.now().millisecondsSinceEpoch,
      isFavorite: ModesRepository.isFavorite(presetId),
    );

    await ModesRepository.setCurrent(preset);

    final bloc = context.read<DeviceBloc>();
    bloc.add(
      SaveAlarmPreset(
        DevicePreset(
          effectId: _effectIdForIndex(index),
          speed: _defaultSpeed,
          brightness: _defaultBrightness,
          r: _fixedOrange.red,
          g: _fixedOrange.green,
          b: _fixedOrange.blue,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> _onFavorite(int index) async {
    await ModesRepository.toggleFavorite('emergency:$index');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final tSeconds =
            (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;

        final isOn = _blinkOn(tSeconds);
        const maxB = 1.0;
        final progress = _controller.value;

        final painters = <Widget>[
          CustomPaint(
            painter: CircleHeadlightPainter(
              progress: progress,
              leftColor: _fixedOrange,
              rightColor: _fixedOrange,
              leftBrightness: maxB,
              rightBrightness: maxB,
              leftEnabled: true,
              rightEnabled: true,
              layout: HeadlightLayout.carSvg,
            ),
          ),
          CustomPaint(
            painter: BlinkHeadlightsPainter(
              isOn: isOn,
              color: _fixedOrange,
              brightness: maxB,
              leftEnabled: true,
              rightEnabled: true,
              layout: HeadlightLayout.carSvg,
            ),
          ),
          PulsationLayer(
            phase: progress,
            color: _fixedOrange,
            maxBrightness: maxB,
            leftEnabled: true,
            rightEnabled: true,
            layout: HeadlightLayout.carSvg,
          ),
        ];

        final previews = <Widget>[
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: CircleHeadlightPainter(
                progress: progress,
                leftColor: _fixedOrange,
                rightColor: _fixedOrange,
                leftBrightness: maxB,
                rightBrightness: maxB,
                leftEnabled: true,
                rightEnabled: false,
                layout: HeadlightLayout.singlePreview,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              painter: BlinkHeadlightsPainter(
                isOn: isOn,
                color: _fixedOrange,
                brightness: 1.0,
                leftEnabled: true,
                rightEnabled: false,
                layout: HeadlightLayout.singlePreview,
              ),
            ),
          ),
          SizedBox(
            width: 180,
            height: 180,
            child: PulsationLayer(
              phase: progress,
              color: _fixedOrange,
              maxBrightness: 1.0,
              leftEnabled: true,
              rightEnabled: false,
              layout: HeadlightLayout.singlePreview,
            ),
          ),
        ];

        return Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Emergency alarm',
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
                        Positioned.fill(child: painters[_currentIndex]),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              height: 330,
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.82),
                itemCount: 3,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, index) {
                  final presetId = 'emergency:$index';
                  final fav = ModesRepository.isFavorite(presetId);

                  final current = ModesRepository.loadCurrent(
                    PresetCategory.alarm, // ✅ було emergency -> alarm
                  );
                  final isSetSelected = current?.id == presetId;

                  return ModeCard(
                    title: _titles[index],
                    isActive: index == _currentIndex,
                    preview: previews[index],
                    showControls: false,
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
