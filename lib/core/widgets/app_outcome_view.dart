import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_outcome_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

// Success vs error chrome (edits, payments, errors)
enum AppOutcomeKind { success, failure }

// Blue check or red X in a circle
class AppOutcomeMark extends StatelessWidget {
  const AppOutcomeMark({
    super.key,
    required this.kind,
    this.size = 56,
  });

  final AppOutcomeKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ok = kind == AppOutcomeKind.success;
    final icon = ok ? Icons.check_rounded : Icons.close_rounded;
    final iconSize =
        AppOutcomeMarkLayout.iconSize(success: ok, markDiameter: size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ok ? AppColors.primaryBlue : AppColors.error,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: iconSize, color: AppColors.onPrimary),
    );
  }
}

// title + message under mark (no buttons)
class AppOutcomeHeadline extends StatelessWidget {
  const AppOutcomeHeadline({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.markSize = 56,
    this.gapAfterMark = AppSpacing.lg,
    this.titleStyle,
    this.messageStyle,
    this.textAlign = TextAlign.center,
  });

  final AppOutcomeKind kind;
  final String title;
  final String message;
  final double markSize;
  final double gapAfterMark;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppOutcomeMark(kind: kind, size: markSize),
        SizedBox(height: gapAfterMark),
        Text(
          title,
          style: titleStyle ?? AppTypography.hubTitle,
          textAlign: textAlign,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          style: messageStyle ?? AppTypography.bodyMuted,
          textAlign: textAlign,
        ),
      ],
    );
  }
}

// centered headline + primary button, or pass actions instead of button
class AppOutcomeView extends StatelessWidget {
  const AppOutcomeView({
    super.key,
    required this.kind,
    required this.message,
    this.title,
    this.buttonLabel = 'Close',
    required this.onClose,
    this.markSize = 56,
    this.gapAfterMark = AppSpacing.lg,
    this.titleStyle,
    this.messageStyle,
    this.actions,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    this.primaryButtonIcon,
  });

  final AppOutcomeKind kind;
  final String message;
  final String? title;
  final String buttonLabel;
  final VoidCallback onClose;
  final IconData? primaryButtonIcon;
  final double markSize;
  final double gapAfterMark;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final Widget? actions;
  final EdgeInsetsGeometry padding;

  String get _resolvedTitle => title ??
      (kind == AppOutcomeKind.success ? 'Success' : 'Something went wrong');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppOutcomeHeadline(
            kind: kind,
            title: _resolvedTitle,
            message: message,
            markSize: markSize,
            gapAfterMark: gapAfterMark,
            titleStyle: titleStyle,
            messageStyle: messageStyle,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (actions != null)
            actions!
          else
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(
                label: buttonLabel,
                icon: primaryButtonIcon,
                onPressed: onClose,
              ),
            ),
        ],
      ),
    );
  }
}
