class TurnMask {
  final bool leftOn;
  final bool rightOn;
  const TurnMask(this.leftOn, this.rightOn);
}

/// 3 ліво → 3 право
TurnMask turnSignalsMask({required double tSeconds, double hz = 3.0}) {
  final step = (tSeconds * hz).floor() % 6;
  return step < 3 ? const TurnMask(true, false) : const TurnMask(false, true);
}
