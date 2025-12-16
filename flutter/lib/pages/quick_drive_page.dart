import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_ui/features/device/bloc/device_bloc.dart';

import '../data/headlight_state.dart';
import '../data/headlight_repository.dart';
import 'widgets/color_wheel_painter.dart';
import 'widgets/headlight_glow.dart';

enum HeadlightSide { both, left, right }

class QuickDriveScreen extends StatefulWidget {
  final HeadlightSide initialSide;

  const QuickDriveScreen({super.key, this.initialSide = HeadlightSide.both});

  @override
  State<QuickDriveScreen> createState() => _QuickDriveScreenState();
}

class _QuickDriveScreenState extends State<QuickDriveScreen> {
  late HeadlightSide _side;

  Color _leftColor = const Color(0xFFFF66FF);
  Color _rightColor = const Color(0xFFFF6666);
  double _leftBrightness = 0.8;
  double _rightBrightness = 0.5;
  bool _lightsEnabled = true;

  Offset _leftPickerOffset = Offset.zero;
  Offset _rightPickerOffset = Offset.zero;

  static const double _wheelSize = 220;
  static const double _wheelRadius = _wheelSize / 2;

  HeadlightSide get _activeSide =>
      _side == HeadlightSide.both ? HeadlightSide.left : _side;

  Offset get _activePickerOffset => _activeSide == HeadlightSide.left
      ? _leftPickerOffset
      : _rightPickerOffset;

  double get _activeBrightness =>
      _activeSide == HeadlightSide.left ? _leftBrightness : _rightBrightness;

  double get _carScale {
    switch (_side) {
      case HeadlightSide.both:
        return 1.0;
      case HeadlightSide.left:
      case HeadlightSide.right:
        return 2.2;
    }
  }

  Color _applyBrightness(Color base, double brightness) {
    final value = _lightsEnabled ? brightness : 0.0;
    final hsv = HSVColor.fromColor(base);
    return hsv.withValue(value.clamp(0.0, 1.0)).toColor();
  }

  Offset _carOffset(Size size) {
    final dxBase = size.width * 0.6;
    final dyBase = size.height * 0.03;
    switch (_side) {
      case HeadlightSide.both:
        return const Offset(0, -20);
      case HeadlightSide.left:
        return Offset(dxBase, -dyBase);
      case HeadlightSide.right:
        return Offset(-dxBase, -dyBase);
    }
  }

  Offset _offsetFromColor(Color color) {
    final hsv = HSVColor.fromColor(color);
    final hue = hsv.hue;
    final sat = hsv.saturation;

    final angleRad = (hue - 180) * math.pi / 180.0;
    final dist = sat * _wheelRadius;

    return Offset(math.cos(angleRad) * dist, math.sin(angleRad) * dist);
  }

  int _b01to255(double v) => (v.clamp(0.0, 1.0) * 255).round().clamp(0, 255);

  void _sendQuickDrive() {
    final bloc = context.read<DeviceBloc>();

    final leftB = _lightsEnabled ? _leftBrightness : 0.0;
    final rightB = _lightsEnabled ? _rightBrightness : 0.0;

    if (_side == HeadlightSide.both) {
      bloc.add(
        SendQuickDriveColor(
          side: BleSide.left,
          r: _leftColor.red,
          g: _leftColor.green,
          b: _leftColor.blue,
          brightness: _b01to255(leftB),
        ),
      );
      bloc.add(
        SendQuickDriveColor(
          side: BleSide.right,
          r: _rightColor.red,
          g: _rightColor.green,
          b: _rightColor.blue,
          brightness: _b01to255(rightB),
        ),
      );
      return;
    }

    if (_side == HeadlightSide.left) {
      bloc.add(
        SendQuickDriveColor(
          side: BleSide.left,
          r: _leftColor.red,
          g: _leftColor.green,
          b: _leftColor.blue,
          brightness: _b01to255(leftB),
        ),
      );
    } else {
      bloc.add(
        SendQuickDriveColor(
          side: BleSide.right,
          r: _rightColor.red,
          g: _rightColor.green,
          b: _rightColor.blue,
          brightness: _b01to255(rightB),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;

    final loaded = HeadlightRepository.load();
    _leftColor = loaded.leftColor;
    _rightColor = loaded.rightColor;
    _leftBrightness = loaded.leftBrightness;
    _rightBrightness = loaded.rightBrightness;
    _lightsEnabled = loaded.lightsEnabled;

    _leftPickerOffset = _offsetFromColor(_leftColor);
    _rightPickerOffset = _offsetFromColor(_rightColor);

    WidgetsBinding.instance.addPostFrameCallback((_) => _sendQuickDrive());
  }

  Future<void> _persist() async {
    final prev = HeadlightRepository.load();
    await HeadlightRepository.save(
      prev.copyWith(
        leftColor: _leftColor,
        rightColor: _rightColor,
        leftBrightness: _leftBrightness,
        rightBrightness: _rightBrightness,
        lightsEnabled: _lightsEnabled,
        activeSource: ActiveModeSource.quick,
        clearActivePresetId: true, // ✅
      ),
    );
  }

  void _toggleSide(HeadlightSide side) {
    setState(() {
      _side = (_side == side) ? HeadlightSide.both : side;
    });

    _sendQuickDrive();
  }

  void _onColorChanged(Color color) {
    setState(() {
      if (_side == HeadlightSide.both) {
        _leftColor = color;
        _rightColor = color;
        _leftPickerOffset = _offsetFromColor(color);
        _rightPickerOffset = _offsetFromColor(color);
      } else if (_activeSide == HeadlightSide.left) {
        _leftColor = color;
        _leftPickerOffset = _offsetFromColor(color);
      } else {
        _rightColor = color;
        _rightPickerOffset = _offsetFromColor(color);
      }
    });

    _persist();
    _sendQuickDrive();
  }

  void _onBrightnessChanged(double value) {
    setState(() {
      if (_side == HeadlightSide.both) {
        _leftBrightness = value;
        _rightBrightness = value;
      } else if (_side == HeadlightSide.left) {
        _leftBrightness = value;
      } else {
        _rightBrightness = value;
      }

      _lightsEnabled = value > 0.0;
    });

    _persist();
    _sendQuickDrive();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _activeSide == HeadlightSide.left
        ? _leftColor
        : _rightColor;

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
            children: [
              _buildTopBar(context),
              Expanded(
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    _buildCarArea(),
                    _buildGlassPanel(activeColor, _activeBrightness, _side),
                  ],
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
        horizontal: 16.0,
      ).copyWith(top: 8, bottom: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Text(
            'Quick  drive',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Noto Sans Telugu UI',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final carHeight = size.height * 0.3;

        return Stack(
          children: [
            Center(
              child: Transform.translate(
                offset: _carOffset(size) + const Offset(0, -50),
                child: Transform.scale(
                  scale: _carScale,
                  child: SizedBox(
                    width: size.width,
                    height: carHeight,
                    child: LayoutBuilder(
                      builder: (context, carConstraints) {
                        final cw = carConstraints.maxWidth;
                        final ch = carConstraints.maxHeight;

                        final leftHeadlightRect = Rect.fromLTWH(
                          cw * 0.13,
                          ch * 0.39,
                          cw * 0.18,
                          ch * 0.18,
                        );

                        final rightHeadlightRect = Rect.fromLTWH(
                          cw * (1 - 0.12 - 0.18),
                          ch * 0.39,
                          cw * 0.18,
                          ch * 0.18,
                        );

                        return Stack(
                          children: [
                            Positioned.fill(
                              child: SvgPicture.asset(
                                'assets/svg/car.svg',
                                fit: BoxFit.contain,
                              ),
                            ),
                            HeadlightGlow(
                              rect: leftHeadlightRect,
                              color: _applyBrightness(
                                _leftColor,
                                _leftBrightness,
                              ),
                              isActive:
                                  _side == HeadlightSide.left ||
                                  _side == HeadlightSide.both,
                              brightness: _lightsEnabled
                                  ? _leftBrightness
                                  : 0.0,
                            ),
                            HeadlightGlow(
                              rect: rightHeadlightRect,
                              color: _applyBrightness(
                                _rightColor,
                                _rightBrightness,
                              ),
                              isActive:
                                  _side == HeadlightSide.right ||
                                  _side == HeadlightSide.both,
                              brightness: _lightsEnabled
                                  ? _rightBrightness
                                  : 0.0,
                            ),
                            Positioned.fromRect(
                              rect: leftHeadlightRect,
                              child: GestureDetector(
                                onTap: () => _toggleSide(HeadlightSide.left),
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                            Positioned.fromRect(
                              rect: rightHeadlightRect,
                              child: GestureDetector(
                                onTap: () => _toggleSide(HeadlightSide.right),
                                child: Container(color: Colors.transparent),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassPanel(
    Color activeColor,
    double activeBrightness,
    HeadlightSide side,
  ) {
    String sideText;
    switch (side) {
      case HeadlightSide.both:
        sideText = 'Both headlights';
        break;
      case HeadlightSide.left:
        sideText = 'Left headlight';
        break;
      case HeadlightSide.right:
        sideText = 'Right headlight';
        break;
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 0.0),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.30),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sideText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildColorWheel(activeColor),
                  const SizedBox(height: 16),
                  _buildBrightnessSlider(activeBrightness),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorWheel(Color activeColor) {
    const double wheelSize = _wheelSize;
    final offset = _activePickerOffset;

    return SizedBox(
      height: wheelSize,
      child: Center(
        child: GestureDetector(
          onPanDown: (d) => _handleColorPick(d.localPosition, wheelSize),
          onPanUpdate: (d) => _handleColorPick(d.localPosition, wheelSize),
          child: SizedBox(
            width: wheelSize,
            height: wheelSize,
            child: Stack(
              children: [
                const CustomPaint(
                  size: Size(wheelSize, wheelSize),
                  painter: ColorWheelPainter(),
                ),
                Positioned(
                  left: wheelSize / 2 + offset.dx - 12,
                  top: wheelSize / 2 + offset.dy - 12,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      color: activeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleColorPick(Offset localPos, double size) {
    final center = Offset(size / 2, size / 2);
    double dx = localPos.dx - center.dx;
    double dy = localPos.dy - center.dy;

    final radius = size / 2;
    double dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) dist = 0.0001;

    if (dist > radius) {
      dx = dx / dist * radius;
      dy = dy / dist * radius;
      dist = radius;
    }

    final rawSat = (dist / radius).clamp(0.0, 1.0);

    // ✅ juicy sat curve
    const double satExp = 0.55;
    final saturation = math.pow(rawSat, satExp).toDouble();

    const double satFloor = 0.06;
    final sat = (satFloor + (1.0 - satFloor) * saturation).clamp(0.0, 1.0);

    final angle = math.atan2(dy, dx);
    final hue = angle * 180 / math.pi + 180;

    final hsv = HSVColor.fromAHSV(1.0, hue, sat, 1.0);
    _onColorChanged(hsv.toColor());
  }

  Widget _buildBrightnessSlider(double activeBrightness) {
    return Row(
      children: [
        const Icon(Icons.lightbulb_outline, color: Colors.white, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.15),
            ),
            child: Slider(
              value: _lightsEnabled ? activeBrightness : 0.0,
              min: 0,
              max: 1,
              onChanged: _onBrightnessChanged,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.lightbulb, color: Colors.white, size: 20),
      ],
    );
  }
}
