import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Selective haptics for CTAs and selection controls.
///
/// Skips when the user prefers reduced motion (`MediaQuery.disableAnimations`).
abstract final class AppFeedback {
  AppFeedback._();

  static bool _skip(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Tab / chip / toggle selection.
  static void selection(BuildContext context) {
    if (_skip(context)) return;
    HapticFeedback.selectionClick();
  }

  /// Primary / secondary CTA confirm.
  static void light(BuildContext context) {
    if (_skip(context)) return;
    HapticFeedback.lightImpact();
  }
}
