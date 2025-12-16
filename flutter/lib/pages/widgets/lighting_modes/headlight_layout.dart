import 'package:flutter/material.dart';

class HeadlightLayout {
  final Offset leftCenter; // dx/dy у відсотках (0..1)
  final Offset rightCenter;
  final double radiusFactor; // множник від width

  const HeadlightLayout({
    required this.leftCenter,
    required this.rightCenter,
    required this.radiusFactor,
  });

  static const carSvg = HeadlightLayout(
    leftCenter: Offset(0.23, 0.48),
    rightCenter: Offset(0.79, 0.48),
    radiusFactor: 0.04,
  );
}
