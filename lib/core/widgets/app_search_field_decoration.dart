import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Shared search field decoration (not barrel-exported).
abstract final class AppSearchFieldDecoration {
  static BorderRadius get radius => BorderRadius.circular(AppRadius.md);

  static BorderSide get idleBorderSide =>
      const BorderSide(color: AppColors.secondaryGrey, width: 1);

  // Standalone outline field (list/hub search).
  static InputDecoration outline({
    required String hintText,
    Widget? suffixIcon,
    BoxConstraints? suffixIconConstraints,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMuted,
      prefixIcon: const Icon(Icons.search, color: AppColors.iconGrey, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
        vertical: 12,
      ),
    );
  }

  // Field embedded inside AppMapSearchCard.
  static InputDecoration mapEmbedded({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMuted.copyWith(fontSize: 14),
      prefixIcon: const Icon(Icons.search, color: AppColors.iconGrey, size: 20),
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 44),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 44),
      filled: true,
      fillColor: AppColors.surface,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 12,
      ),
      isDense: true,
    );
  }
}
