// lib/pages/lighting_modes_tab.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/lighting_modes.dart';
import 'widgets/mode_card.dart';
import 'widgets/lighting_modes/lighting_modes_engine.dart';
import 'widgets/color_wheel_dialog.dart';

import '../data/mode_preset.dart';
import '../data/modes_repository.dart';
import '../data/headlight_repository.dart';
import '../data/headlight_state.dart';

import '../features/device/bloc/device_bloc.dart';

class LightingModesTab extends StatefulWidget {
  const LightingModesTab({super.key});

  @override
  State<LightingModesTab> createState() => _LightingModesTabState();
}

class _LightingModesTabState extends State<LightingModesTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  int _currentIndex = 0;

  final List<LightingModeConfig> _modes = [
    LightingModeConfig(
      type: LightingModeType.circle,
      title: 'Circle',
      color1: Colors.orange,
      color2: Colors.orange,
      speed: 0.5,
      brightness: 1.0,
    ),
    LightingModeConfig(
      type: LightingModeType.rainbow,
      title: 'Rainbow',
      color1: Colors.orange,
      color2: Colors.orange,
      speed: 0.5,
      brightness: 1.0,
    ),
    LightingModeConfig(
      type: LightingModeType.gradient,
      title: 'Gradient',
      color1: Colors.orange,
      color2: Colors.purple,
      speed: 0.5,
      brightness: 1.0,
    ),
    LightingModeConfig(
      type: LightingModeType.blinking,
      title: 'Blinking',
      color1: Colors.orange,
      color2: Colors.orange,
      speed: 0.5,
      brightness: 1.0,
    ),
    LightingModeConfig(
      type: LightingModeType.pulsation,
      title: 'Pulsation',
      color1: Colors.orange,
      color2: Colors.orange,
      speed: 0.5,
      brightness: 1.0,
    ),
  ];

  LightingModeConfig get _activeMode => _modes[_currentIndex];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<LightingModeConfig?> _pickColor1(LightingModeConfig mode) async {
    final result = await showColorWheelDialog(context, mode.color1);
    if (result == null) return null;
    return mode.copyWith(color1: result);
  }

  Future<LightingModeConfig?> _pickColor2(LightingModeConfig mode) async {
    final result = await showColorWheelDialog(context, mode.color2);
    if (result == null) return null;
    return mode.copyWith(color2: result);
  }

  int _effectIdForLighting(LightingModeType t) {
    // ESP mapping:
    // 0 static, 1 circle, 2 blink, 3 pulsation, 4 rainbow, 5 chase
    switch (t) {
      case LightingModeType.circle:
        return 1;
      case LightingModeType.blinking:
        return 2;
      case LightingModeType.pulsation:
        return 3;
      case LightingModeType.rainbow:
        return 4;
      case LightingModeType.gradient:
        return 5; // closest on ESP (gradient в UI, на ESP буде chase одним кольором)
    }
  }

  int _to8(double v01) => (v01 * 255).round().clamp(0, 255);

  Future<void> _applyLightingToBle(LightingModeConfig mode) async {
    final effectId = _effectIdForLighting(mode.type);
    final speed8 = _to8(mode.speed);
    final br8 = _to8(mode.brightness);

    // Для rainbow ESP ігнорує RGB (він сам малює rainbow), але можна слати anyway
    final c = mode.color1;

    final bloc = context.read<DeviceBloc>();
    bloc.add(
      SendDynamicEffect(
        effectId: effectId,
        speed: speed8,
        brightness: br8,
        r: c.red,
        g: c.green,
        b: c.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget headlightLayer(HeadlightFrame frame) {
      switch (_activeMode.type) {
        case LightingModeType.circle:
          return CustomPaint(
            painter: CircleHeadlightPainter(
              leftColor: frame.left,
              rightColor: frame.right,
              progress: frame.progress,
              leftBrightness: _activeMode.brightness,
              rightBrightness: _activeMode.brightness,
            ),
          );

        case LightingModeType.rainbow:
          return CustomPaint(
            painter: RainbowRingPainter(
              progress: frame.progress,
              brightness: _activeMode.brightness,
            ),
          );

        case LightingModeType.blinking:
          return CustomPaint(
            painter: BlinkHeadlightsPainter(
              isOn: frame.left.opacity > 0.01,
              color: frame.left,
              brightness: _activeMode.brightness,
            ),
          );

        case LightingModeType.pulsation:
          return PulsationLayer(
            phase: _controller.value,
            color: frame.left,
            maxBrightness: _activeMode.brightness,
          );

        case LightingModeType.gradient:
          return CustomPaint(
            painter: GradientRingPainter(
              progress: frame.progress,
              brightness: _activeMode.brightness,
              startColor: _activeMode.color1,
              endColor: _activeMode.color2,
            ),
          );
      }
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final mode = _activeMode;
        final frame = buildHeadlightFrame(mode, _controller.value);

        return Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Lighting modes',
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
                        Positioned.fill(child: headlightLayer(frame)),
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
                controller: PageController(viewportFraction: 0.8),
                itemCount: _modes.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, index) {
                  final mode = _modes[index];
                  final isActive = index == _currentIndex;

                  final presetId = 'lighting:${mode.type.name}:${mode.title}';

                  final current = ModesRepository.loadCurrent(
                    PresetCategory.lighting,
                  );
                  final isSetSelected = current?.id == presetId;

                  final fav = ModesRepository.isFavorite(presetId);

                  return ModeCard(
                    title: mode.title,
                    isActive: isActive,
                    showControls: true,
                    isFavorite: fav,
                    isSetSelected: isSetSelected,

                    color: mode.color1,
                    onColorTap: mode.type == LightingModeType.rainbow
                        ? null
                        : () async {
                            final updated = await _pickColor1(mode);
                            if (updated == null) return;
                            setState(() => _modes[index] = updated);
                          },

                    endColor: mode.type == LightingModeType.gradient
                        ? mode.color2
                        : null,
                    onEndColorTap: mode.type == LightingModeType.gradient
                        ? () async {
                            final updated = await _pickColor2(mode);
                            if (updated == null) return;
                            setState(() => _modes[index] = updated);
                          }
                        : null,

                    speed: mode.speed,
                    onSpeedChanged: (v) =>
                        setState(() => _modes[index] = mode.copyWith(speed: v)),

                    brightness: mode.brightness,
                    onBrightnessChanged: (v) => setState(
                      () => _modes[index] = mode.copyWith(brightness: v),
                    ),

                    onSet: () async {
                      final preset = ModePreset(
                        id: presetId,
                        category: PresetCategory.lighting,
                        title: mode.title,
                        effectId: _effectIdForLighting(mode.type),
                        speed: _to8(mode.speed),
                        brightness: _to8(mode.brightness),
                        color: mode.color1,
                        savedAtMs: DateTime.now().millisecondsSinceEpoch,
                        isFavorite: ModesRepository.isFavorite(presetId),
                      );

                      await ModesRepository.setCurrent(preset);

                      // ✅ lighting став головним, і запам'ятали presetId
                      await HeadlightRepository.setActiveLightingPreset(
                        preset.id,
                      );

                      // ✅ одразу шлемо на ESP (0x02)
                      await _applyLightingToBle(mode);

                      if (mounted) setState(() {});
                    },

                    onFavorite: () async {
                      await ModesRepository.toggleFavorite(presetId);
                      setState(() {});
                    },
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

class CircleHeadlightPainter extends CustomPainter {
  final Color leftColor;
  final Color rightColor;
  final double progress;
  final double leftBrightness;
  final double rightBrightness;

  const CircleHeadlightPainter({
    required this.leftColor,
    required this.rightColor,
    required this.progress,
    this.leftBrightness = 1.0,
    this.rightBrightness = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final leftCenter = Offset(size.width * 0.23, size.height * 0.48);
    final rightCenter = Offset(size.width * 0.79, size.height * 0.48);

    final radius = size.width * 0.03;
    const leftStart = -math.pi / 2;
    const rightStart = 4 * math.pi / 4;

    _drawArcGlow(
      canvas,
      center: leftCenter,
      radius: radius,
      prog: progress,
      color: leftColor,
      brightness: leftBrightness,
      startOffset: leftStart,
    );

    _drawArcGlow(
      canvas,
      center: rightCenter,
      radius: radius,
      prog: -progress,
      color: rightColor,
      brightness: rightBrightness,
      startOffset: rightStart,
    );
  }

  void _drawArcGlow(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required double prog,
    required Color color,
    required double brightness,
    required double startOffset,
  }) {
    const sweep = math.pi / 2;
    final startAngle = startOffset + prog * 2 * math.pi;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final glowIntensity = (brightness * 2.2).clamp(0.4, 2.4);
    final glowColor = color.withOpacity(0.9);

    final outerGlow = Paint()
      ..color = glowColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 1.3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawArc(rect, startAngle, sweep, false, outerGlow);

    final midGlow = Paint()
      ..color = glowColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.9
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawArc(rect, startAngle, sweep, false, midGlow);

    final border = Paint()
      ..color = Colors.white.withOpacity(brightness.clamp(0.03, 0.95))
      ..strokeWidth = lerpDouble(3, 6, brightness)!
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.95),
      startAngle,
      sweep,
      false,
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CircleHeadlightPainter old) =>
      old.leftColor != leftColor ||
      old.rightColor != rightColor ||
      old.progress != progress ||
      old.leftBrightness != leftBrightness ||
      old.rightBrightness != rightBrightness;
}

class RainbowRingPainter extends CustomPainter {
  final double progress;
  final double brightness;

  const RainbowRingPainter({required this.progress, required this.brightness});

  @override
  void paint(Canvas canvas, Size size) {
    final b = brightness.clamp(0.0, 1.0);
    if (b <= 0.001) return;

    final leftCenter = Offset(size.width * 0.23, size.height * 0.48);
    final rightCenter = Offset(size.width * 0.79, size.height * 0.48);
    final radius = size.width * 0.03;

    final leftAngle = (-math.pi / 2) + progress * 2 * math.pi;
    final rightAngle = (-math.pi / 2) - progress * 2 * math.pi;

    _drawRainbowRing(canvas, leftCenter, radius, leftAngle, b);
    _drawRainbowRing(canvas, rightCenter, radius, rightAngle, b);
  }

  void _drawRainbowRing(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double b,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    const colors = <Color>[
      Color.fromARGB(255, 255, 0, 0),
      Color.fromARGB(255, 255, 255, 0),
      Color.fromARGB(255, 0, 255, 0),
      Color.fromARGB(255, 0, 255, 255),
      Color.fromARGB(255, 0, 0, 255),
      Color.fromARGB(255, 255, 0, 255),
      Color.fromARGB(255, 255, 0, 0),
    ];

    final shader = SweepGradient(
      colors: colors,
      transform: GradientRotation(angle),
    ).createShader(rect);

    final glowIntensity = (b * 2.2);

    final outerGlow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 1.3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * glowIntensity)
      ..blendMode = BlendMode.plus
      ..color = Colors.white.withOpacity(0.8 * b);

    canvas.drawCircle(center, radius, outerGlow);

    final midGlow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.9
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * glowIntensity)
      ..blendMode = BlendMode.plus
      ..color = Colors.white.withOpacity(0.65 * b);

    canvas.drawCircle(center, radius, midGlow);

    if (b > 0.02) {
      final border = Paint()
        ..color = Colors.white.withOpacity(brightness.clamp(0.03, 0.95))
        ..strokeWidth = lerpDouble(3, 6, brightness)!
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(center, radius * 0.98, border);
    }
  }

  @override
  bool shouldRepaint(covariant RainbowRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.brightness != brightness;
  }
}

class GradientRingPainter extends CustomPainter {
  final double progress;
  final double brightness;
  final Color startColor;
  final Color endColor;

  const GradientRingPainter({
    required this.progress,
    required this.brightness,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final b = brightness.clamp(0.0, 1.0);
    if (b <= 0.001) return;

    final leftCenter = Offset(size.width * 0.23, size.height * 0.48);
    final rightCenter = Offset(size.width * 0.79, size.height * 0.48);
    final radius = size.width * 0.03;

    final leftAngle = (-math.pi / 2) + progress * 2 * math.pi;
    final rightAngle = (-math.pi / 2) - progress * 2 * math.pi;

    _drawGradientRing(canvas, leftCenter, radius, leftAngle, b);
    _drawGradientRing(canvas, rightCenter, radius, rightAngle, b);
  }

  void _drawGradientRing(
    Canvas canvas,
    Offset center,
    double radius,
    double angle,
    double b,
  ) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    final colors = <Color>[
      startColor.withOpacity(b),
      endColor.withOpacity(b),
      startColor.withOpacity(b),
    ];

    final shader = SweepGradient(
      colors: colors,
      transform: GradientRotation(angle),
    ).createShader(rect);

    final glowIntensity = (b * 2.2);

    final outerGlow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 1.3
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * glowIntensity)
      ..color = Colors.white
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(center, radius, outerGlow);

    final midGlow = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.9
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * glowIntensity)
      ..color = Colors.white
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(center, radius, midGlow);

    final core = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.45
      ..strokeCap = StrokeCap.round
      ..color = Colors.white
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(center, radius, core);

    if (b > 0.02) {
      final border = Paint()
        ..color = Colors.white.withOpacity((0.12 + 0.55 * b).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(1.5, 5.0, b)!;

      canvas.drawCircle(center, radius * 0.98, border);
    }
  }

  @override
  bool shouldRepaint(covariant GradientRingPainter old) {
    return old.progress != progress ||
        old.brightness != brightness ||
        old.startColor != startColor ||
        old.endColor != endColor;
  }
}

class BlinkHeadlightsPainter extends CustomPainter {
  final bool isOn;
  final Color color;
  final double brightness;

  const BlinkHeadlightsPainter({
    required this.isOn,
    required this.color,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final b = brightness.clamp(0.0, 1.0);
    if (!isOn || b <= 0.001) return;

    final leftCenter = Offset(size.width * 0.23, size.height * 0.48);
    final rightCenter = Offset(size.width * 0.79, size.height * 0.48);
    final radius = size.width * 0.04;

    _drawHeadlight(canvas, leftCenter, radius, b);
    _drawHeadlight(canvas, rightCenter, radius, b);
  }

  void _drawHeadlight(Canvas canvas, Offset center, double r, double b) {
    final clipRect = Rect.fromCircle(center: center, radius: r * 2);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(clipRect, Radius.circular(r)));

    final glowIntensity = b * 2.2;

    final innerGlow = Paint()
      ..color = color.withOpacity(0.95 * b)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * glowIntensity)
      ..blendMode = BlendMode.plus;

    canvas.drawCircle(center, r * 0.9, innerGlow);

    final ring = Paint()
      ..color = Colors.white.withOpacity((0.35 + 0.65 * b).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(1.5, 5.0, b)!;

    canvas.drawCircle(center, r * 0.70, ring);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PulsationLayer extends StatelessWidget {
  final double phase;
  final Color color;
  final double maxBrightness;

  const PulsationLayer({
    super.key,
    required this.phase,
    required this.color,
    required this.maxBrightness,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;

        final maxB = maxBrightness.clamp(0.0, 1.0);
        if (maxB <= 0.001) return const SizedBox.shrink();

        final pulse01 = (math.sin(phase * 2 * math.pi) + 1) / 2;
        final b = pulse01 * maxB;
        if (b <= 0.001) return const SizedBox.shrink();

        final leftCenter = Offset(w * 0.23, h * 0.48);
        final rightCenter = Offset(w * 0.79, h * 0.48);

        final r = w * 0.04;
        final box = r * 4.2;

        Rect rectFromCenter(Offset center) =>
            Rect.fromCenter(center: center, width: box, height: box);

        Widget headlight(Rect rect) {
          return Positioned.fromRect(
            rect: rect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(r),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.85,
                    colors: [color.withOpacity(0.55 * b), Colors.transparent],
                  ),
                ),
              ),
            ),
          );
        }

        return Stack(
          children: [
            headlight(rectFromCenter(leftCenter)),
            headlight(rectFromCenter(rightCenter)),
          ],
        );
      },
    );
  }
}
