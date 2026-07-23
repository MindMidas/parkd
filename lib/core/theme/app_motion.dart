import 'package:flutter/animation.dart';

/// Shared durations and curves for navigation, sheets, and micro-motion.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration press = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration nav = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 280);
  static const Duration sheet = Duration(milliseconds: 300);

  /// Pressed control scale (Airbnb/Robinhood restrained).
  static const double pressScale = 0.97;

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve decelerate = Curves.easeOut;
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve spring = Curves.easeOutBack;
}
