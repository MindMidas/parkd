import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class AppMessenger {
  AppMessenger._();

  static void showSuccess(BuildContext context, String message) {
    _show(ScaffoldMessenger.of(context), message);
  }

  static void showSuccessFor(ScaffoldMessengerState messenger, String message) {
    _show(messenger, message);
  }

  static void _show(ScaffoldMessengerState messenger, String message) {
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.snackBarContent),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
      ),
    );
  }
}
