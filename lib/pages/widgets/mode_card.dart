import 'package:flutter/material.dart';

class ModeCard extends StatelessWidget {
  final String title;
  final bool isActive;

  // Центровий preview (для turn signals / alarm / power-on)
  final Widget? preview;

  // Кнопки
  final VoidCallback onSet;
  final VoidCallback onFavorite;
  final bool isFavorite;
  // ✅ НОВЕ: чи цей режим зараз встановлений (Set підсвічується)
  final bool isSetSelected;

  // Якщо true — показує контролі (color picker / sliders)
  final bool showControls;

  // --- Controls (опційно) ---
  final Color? color;
  final VoidCallback? onColorTap;

  final Color? endColor;
  final VoidCallback? onEndColorTap;

  final double? speed;
  final ValueChanged<double>? onSpeedChanged;

  final double? brightness;
  final ValueChanged<double>? onBrightnessChanged;

  const ModeCard({
    super.key,
    required this.title,
    required this.isActive,
    required this.onSet,
    required this.onFavorite,
    this.preview,
    this.isSetSelected = false,
    this.showControls = false,
    this.color,
    this.onColorTap,
    this.endColor,
    this.onEndColorTap,
    this.speed,
    this.onSpeedChanged,
    this.brightness,
    this.onBrightnessChanged,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ блакитний для selected
    const selectedBlue = Color(0xFF44B6FF);

    return AnimatedScale(
      scale: isActive ? 1.0 : 0.9,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 250),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2B3559), Color(0xFF191F3B)],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.30),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (preview != null) ...[
                    SizedBox(height: 120, child: Center(child: preview)),
                    const SizedBox(height: 12),
                  ],

                  if (showControls) ...[
                    _ColorRow(
                      color: color,
                      onColorTap: onColorTap,
                      endColor: endColor,
                      onEndColorTap: onEndColorTap,
                    ),
                    const SizedBox(height: 16),

                    if (speed != null && onSpeedChanged != null) ...[
                      _LabeledSlider(
                        label: 'Speed',
                        value: speed!,
                        onChanged: onSpeedChanged!,
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (brightness != null && onBrightnessChanged != null) ...[
                      _LabeledSlider(
                        label: 'Brightness',
                        value: brightness!,
                        onChanged: onBrightnessChanged!,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],

                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSetSelected
                              ? selectedBlue
                              : Colors.transparent,
                          side: BorderSide(
                            color: isSetSelected ? selectedBlue : Colors.white,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                        ),
                        onPressed: onSet,
                        child: Text(
                          'Set',
                          style: TextStyle(
                            color: isSetSelected ? Colors.white : Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onFavorite,
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Color(0xFF44B6FF) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final Color? color;
  final VoidCallback? onColorTap;
  final Color? endColor;
  final VoidCallback? onEndColorTap;

  const _ColorRow({
    this.color,
    this.onColorTap,
    this.endColor,
    this.onEndColorTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasStart = onColorTap != null && color != null;
    final hasEnd = onEndColorTap != null && endColor != null;

    if (!hasStart && !hasEnd) return const SizedBox.shrink();

    if (hasStart && hasEnd) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ColorPickItem(label: 'Start color', c: color!, onTap: onColorTap!),
          _ColorPickItem(
            label: 'End color',
            c: endColor!,
            onTap: onEndColorTap!,
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _ColorPickItem(
          label: hasStart ? 'Color' : 'End color',
          c: hasStart ? color! : endColor!,
          onTap: hasStart ? onColorTap! : onEndColorTap!,
        ),
      ],
    );
  }
}

class _ColorPickItem extends StatelessWidget {
  final String label;
  final Color c;
  final VoidCallback onTap;

  const _ColorPickItem({
    required this.label,
    required this.c,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white12,
          ),
          child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
        ),
      ],
    );
  }
}
