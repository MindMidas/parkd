// Icon size vs circle diameter for outcome marks (check / X)
abstract final class AppOutcomeMarkLayout {
  static double iconSize({
    required bool success,
    required double markDiameter,
  }) {
    return markDiameter * (success ? (20 / 56) : (28 / 72));
  }
}
