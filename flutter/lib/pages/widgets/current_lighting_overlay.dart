import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/mode_preset.dart';

class CurrentLightingOverlay extends StatefulWidget {
  const CurrentLightingOverlay({
    super.key,
    required this.preset,
    required this.enabled,
  });

  final ModePreset preset;
  final bool enabled;

  @override
  State<CurrentLightingOverlay> createState() => _CurrentLightingOverlayState();
}

class _CurrentLightingOverlayState extends State<CurrentLightingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    // просто візуалізація в UI (не впливає на BLE)
    final base = widget.preset.color;
    final br = (widget.preset.brightness / 255.0).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;

        double glow = br;
        switch (widget.preset.effectId) {
          case 2: // blink
            glow = (t < 0.5 ? br : 0.0);
            break;
          case 3: // pulse
            glow = br * (0.35 + 0.65 * (0.5 - 0.5 * math.cos(t * 2 * math.pi)));
            break;
          default:
            glow = br;
        }

        return IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.85,
                colors: [base.withOpacity(0.55 * glow), Colors.transparent],
              ),
            ),
          ),
        );
      },
    );
  }
}
