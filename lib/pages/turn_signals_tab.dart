import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_ui/pages/widgets/mode_card.dart';
import 'package:flutter_ui/pages/widgets/turn_alarm_effects.dart';

import 'package:flutter_ui/data/mode_preset.dart';
import 'package:flutter_ui/data/modes_repository.dart';

import 'package:flutter_ui/features/device/bloc/device_bloc.dart';

class TurnSignalsTab extends StatefulWidget {
  const TurnSignalsTab({super.key});

  @override
  State<TurnSignalsTab> createState() => _TurnSignalsTabState();
}

class _TurnSignalsTabState extends State<TurnSignalsTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentIndex = 0;

  static const _titles = ['Circle', 'Blink', 'Pulsation'];

  // turn — тільки orange
  static const Color _fixedOrange = Color(0xFFFF7800);

  // EEPROM дефолти (можеш змінити)
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

  int _effectIdForIndex(int index) => index.clamp(0, 2);

  _SignalState _signalState(double tSeconds) {
    const blinkPeriod = 1.0;
    const onWindow = 0.5;
    const sideWindow = 3.0;

    final isLeftPhase = (tSeconds % (sideWindow * 2)) < sideWindow;
    final local = tSeconds % sideWindow;
    final isOn = (local % blinkPeriod) < onWindow;

    return _SignalState(
      leftEnabled: isLeftPhase,
      rightEnabled: !isLeftPhase,
      isOn: isOn,
    );
  }

  Future<void> _onSet(int index) async {
    final presetId = 'turn:$index';

    // 1) Hive current
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

    // 2) BLE -> EEPROM (Turn)
    final bloc = context.read<DeviceBloc>();
    bloc.add(
      SaveTurnPreset(
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
    await ModesRepository.toggleFavorite('turn:$index');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final tSeconds =
            (_controller.lastElapsedDuration?.inMilliseconds ?? 0) / 1000.0;

        final sig = _signalState(tSeconds);
        final sp = _sidePhase(tSeconds);

        const maxB = 1.0;

        // 3 цикли на сторону
        final circleProgress = sp.local01 * 3.0;
        final pulsePhase = sp.local01 * 3.0;

        final carPainters = <Widget>[
          CustomPaint(
            painter: CircleHeadlightPainter(
              progress: circleProgress,
              leftColor: _fixedOrange,
              rightColor: _fixedOrange,
              leftBrightness: maxB,
              rightBrightness: maxB,
              leftEnabled: sp.leftEnabled,
              rightEnabled: sp.rightEnabled,
              layout: HeadlightLayout.carSvg,
            ),
          ),
          CustomPaint(
            painter: BlinkHeadlightsPainter(
              isOn: sig.isOn,
              color: _fixedOrange,
              brightness: maxB,
              leftEnabled: sig.leftEnabled,
              rightEnabled: sig.rightEnabled,
              layout: HeadlightLayout.carSvg,
            ),
          ),
          PulsationLayer(
            phase: pulsePhase,
            color: _fixedOrange,
            maxBrightness: maxB,
            leftEnabled: sp.leftEnabled,
            rightEnabled: sp.rightEnabled,
            layout: HeadlightLayout.carSvg,
          ),
        ];

        final previews = <Widget>[
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: CircleHeadlightPainter(
                progress: circleProgress,
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
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: BlinkHeadlightsPainter(
                isOn: sig.isOn,
                color: _fixedOrange,
                brightness: 1.0,
                leftEnabled: true,
                rightEnabled: false,
                layout: HeadlightLayout.singlePreview,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            height: 220,
            child: PulsationLayer(
              phase: pulsePhase,
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
              'Turn signals',
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
                        Positioned.fill(child: carPainters[_currentIndex]),
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
                  final presetId = 'turn:$index';
                  final fav = ModesRepository.isFavorite(presetId);
                  final current = ModesRepository.loadCurrent(
                    PresetCategory.turn,
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

class _SignalState {
  final bool leftEnabled;
  final bool rightEnabled;
  final bool isOn;

  const _SignalState({
    required this.leftEnabled,
    required this.rightEnabled,
    required this.isOn,
  });
}

class _SidePhase {
  final bool leftEnabled;
  final bool rightEnabled;
  final double local01;
  const _SidePhase(this.leftEnabled, this.rightEnabled, this.local01);
}

_SidePhase _sidePhase(double tSeconds) {
  const sideWindow = 3.0;
  final inLeft = (tSeconds % (sideWindow * 2)) < sideWindow;
  final localSec = tSeconds % sideWindow;
  final local01 = (localSec / sideWindow).clamp(0.0, 1.0);
  return _SidePhase(inLeft, !inLeft, local01);
}
