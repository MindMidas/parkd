import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Shared 12px outline + borders for AppSearchField and AppMapSearchField (not barrel-exported)
abstract final class AppSearchFieldDecoration {
  static const BorderRadius radius = BorderRadius.all(Radius.circular(12));

  static BorderSide get idleBorderSide =>
      BorderSide(color: AppColors.iconGrey.withValues(alpha: 0.22), width: 1);

  static InputDecoration outline({
    required String hintText,
    Widget? suffixIcon,
    BoxConstraints? suffixIconConstraints,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMuted,
      prefixIcon: const Icon(Icons.search, color: AppColors.iconGrey, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 32),
      suffixIcon: suffixIcon,
      suffixIconConstraints: suffixIconConstraints,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: idleBorderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: idleBorderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: idleBorderSide,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 8,
      ),
    );
  }
}
