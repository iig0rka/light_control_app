import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'color_wheel_painter.dart';

class ColorWheelDialog extends StatefulWidget {
  final Color initial;

  const ColorWheelDialog({super.key, required this.initial});

  @override
  State<ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<ColorWheelDialog> {
  late HSVColor _hsv;
  static const double _wheelSize = 320;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  void _handlePan(Offset localPos) {
    final center = Offset(_wheelSize / 2, _wheelSize / 2);
    double dx = localPos.dx - center.dx;
    double dy = localPos.dy - center.dy;

    final radius = _wheelSize / 2;
    double dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) dist = 0.0001;

    // обмежуємо палець радіусом кола
    if (dist > radius) {
      dx = dx / dist * radius;
      dy = dy / dist * radius;
      dist = radius;
    }

    final angle = math.atan2(dy, dx); // -pi..pi
    double hue = angle * 180 / math.pi + 180; // 0..360
    double saturation = (dist / radius).clamp(0.0, 1.0);

    setState(() {
      _hsv = HSVColor.fromAHSV(_hsv.alpha, hue, saturation, _hsv.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // сам круг
          SizedBox(
            width: _wheelSize,
            height: _wheelSize,
            child: GestureDetector(
              onPanDown: (d) => _handlePan(d.localPosition),
              onPanUpdate: (d) => _handlePan(d.localPosition),
              child: Stack(
                children: [
                  const CustomPaint(
                    size: Size(_wheelSize, _wheelSize),
                    painter: ColorWheelPainter(),
                  ),
                  // пін
                  Positioned(
                    left:
                        _wheelSize / 2 +
                        -1 *
                            math.cos(_hsv.hue * math.pi / 180) *
                            _hsv.saturation *
                            (_wheelSize / 2) -
                        14,
                    top:
                        _wheelSize / 2 +
                        -1 *
                            math.sin(_hsv.hue * math.pi / 180) *
                            _hsv.saturation *
                            (_wheelSize / 2) -
                        14,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // прев’ю кольору + кнопки
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop<Color?>(null),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A2340),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop<Color>(color),
                child: const Text('OK'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// хелпер, щоб викликати діалог
Future<Color?> showColorWheelDialog(BuildContext context, Color initial) {
  return showDialog<Color>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ColorWheelDialog(initial: initial),
  );
}
