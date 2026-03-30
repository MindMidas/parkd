// Filled + outlined actions
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/display_formatting.dart';

abstract final class AppButtonStyleTokens {
  static const EdgeInsets symmetricPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.applyTitleCase = true,
    this.loading = false,
    this.iconTrailing = false,
    this.fullWidth = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool applyTitleCase;
  final bool loading;
  final bool iconTrailing;
  final bool fullWidth;
  final bool compact;

  String get _displayLabel =>
      applyTitleCase ? formatTitleCaseWords(label) : label;

  @override
  Widget build(BuildContext context) {
    final effectiveOn = loading ? null : onPressed;

    if (compact) {
      final compactStyle = FilledButton.styleFrom(
        minimumSize: Size(fullWidth ? double.infinity : 0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: AppTypography.buttonDense,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.secondaryGrey,
        disabledForegroundColor: AppColors.iconGrey,
      );
      if (loading) {
        return FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(
            minimumSize: Size(fullWidth ? double.infinity : 0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            textStyle: AppTypography.buttonDense,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primaryBlue,
            disabledForegroundColor: AppColors.onPrimary,
          ),
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.onPrimary,
            ),
          ),
        );
      }
      if (icon == null) {
        return FilledButton(
          onPressed: effectiveOn,
          style: compactStyle,
          child: Text(_displayLabel),
        );
      }
      return FilledButton.icon(
        onPressed: effectiveOn,
        style: compactStyle,
        icon: Icon(icon, size: 18),
        label: Text(_displayLabel),
      );
    }

    final minSize = Size(
      fullWidth ? double.infinity : 0,
      AppSpacing.primaryButtonMinHeight,
    );
    final style = FilledButton.styleFrom(
      minimumSize: minSize,
      padding: AppButtonStyleTokens.symmetricPadding,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: AppTypography.button,
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: AppColors.onPrimary,
      disabledBackgroundColor: AppColors.secondaryGrey,
      disabledForegroundColor: AppColors.iconGrey,
    );

    if (loading) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          padding: AppButtonStyleTokens.symmetricPadding,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: AppTypography.button,
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primaryBlue,
          disabledForegroundColor: AppColors.onPrimary,
        ),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.onPrimary,
          ),
        ),
      );
    }

    if (icon != null && iconTrailing) {
      return FilledButton(
        onPressed: effectiveOn,
        style: style,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Text(
              _displayLabel,
              style: AppTypography.button.copyWith(color: AppColors.onPrimary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(icon, size: 22, color: AppColors.onPrimary),
          ],
        ),
      );
    }

    if (icon == null) {
      return FilledButton(
        onPressed: effectiveOn,
        style: style,
        child: Text(_displayLabel),
      );
    }

    return FilledButton.icon(
      onPressed: effectiveOn,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(_displayLabel),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.applyTitleCase = true,
    this.loading = false,
    this.fullWidth = true,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool applyTitleCase;
  final bool loading;
  final bool fullWidth;
  final bool destructive;

  String get _displayLabel =>
      applyTitleCase ? formatTitleCaseWords(label) : label;

  @override
  Widget build(BuildContext context) {
    final effectiveOn = loading ? null : onPressed;
    final minSize = Size(
      fullWidth ? double.infinity : 0,
      AppSpacing.primaryButtonMinHeight,
    );
    final style = OutlinedButton.styleFrom(
      minimumSize: minSize,
      padding: AppButtonStyleTokens.symmetricPadding,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: AppTypography.button,
      foregroundColor: destructive ? AppColors.error : null,
      side: destructive
          ? const BorderSide(color: AppColors.error)
          : null,
    );

    final progressColor =
        destructive ? AppColors.error : AppColors.primaryBlue;

    if (loading) {
      return OutlinedButton(
        onPressed: null,
        style: style,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: progressColor,
          ),
        ),
      );
    }

    if (icon == null) {
      return OutlinedButton(
        onPressed: effectiveOn,
        style: style,
        child: Text(_displayLabel),
      );
    }

    return OutlinedButton.icon(
      onPressed: effectiveOn,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(_displayLabel),
    );
  }
}
