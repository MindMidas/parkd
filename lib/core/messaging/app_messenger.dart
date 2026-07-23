import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Central place for brief user feedback (snackbars). Use from any [BuildContext]
/// under a [ScaffoldMessenger], or pass [ScaffoldMessengerState] when the route
/// context is gone (e.g. after closing a dialog)
class AppMessenger {
  AppMessenger._();

  static void showError(BuildContext context, String message) {
    _show(ScaffoldMessenger.of(context), message, _Kind.error);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(ScaffoldMessenger.of(context), message, _Kind.success);
  }

  static void showErrorFor(ScaffoldMessengerState messenger, String message) {
    _show(messenger, message, _Kind.error);
  }

  static void showSuccessFor(ScaffoldMessengerState messenger, String message) {
    _show(messenger, message, _Kind.success);
  }

  static void _show(
    ScaffoldMessengerState messenger,
    String message,
    _Kind kind,
  ) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.snackBarContent),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kind == _Kind.error
            ? AppColors.error
            : AppColors.success,
      ),
    );
  }
}

enum _Kind { error, success }
