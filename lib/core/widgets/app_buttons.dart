// Filled + outlined actions
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';
import '../utils/display_formatting.dart';

abstract final class AppButtonStyleTokens {
  static const EdgeInsets symmetricPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  static Color get disabledPrimaryFill => AppColors.primaryBlueMuted;
  static Color get disabledPrimaryFg => AppColors.onPrimary;
  static Color get disabledSecondaryFg => AppColors.iconGrey;

  static Color? filledOverlay(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return AppColors.transparent;
    if (states.contains(WidgetState.pressed)) {
      return AppColors.primaryBlueDark.withValues(alpha: 0.32);
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return AppColors.onPrimary.withValues(alpha: 0.12);
    }
    return null;
  }

  static Color? outlinedOverlay({
    required Set<WidgetState> states,
    required bool destructive,
  }) {
    if (states.contains(WidgetState.disabled)) return AppColors.transparent;
    if (states.contains(WidgetState.pressed)) {
      return destructive
          ? AppColors.error.withValues(alpha: 0.12)
          : AppColors.secondaryBlue.withValues(alpha: 0.85);
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return destructive
          ? AppColors.error.withValues(alpha: 0.08)
          : AppColors.secondaryBlue.withValues(alpha: 0.45);
    }
    return null;
  }

  static ButtonStyle filled({
    required Size minimumSize,
    required EdgeInsetsGeometry padding,
    required TextStyle textStyle,
    BorderRadius? borderRadius,
    VisualDensity? visualDensity,
    MaterialTapTargetSize tapTargetSize = MaterialTapTargetSize.shrinkWrap,
    bool destructive = false,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.md);
    final fill = destructive ? AppColors.error : AppColors.primaryBlue;
    final fillPressed = destructive
        ? AppColors.error.withValues(alpha: 0.85)
        : AppColors.primaryBlueDark;
    return FilledButton.styleFrom(
      minimumSize: minimumSize,
      padding: padding,
      tapTargetSize: tapTargetSize,
      visualDensity: visualDensity,
      textStyle: textStyle,
      backgroundColor: fill,
      foregroundColor: AppColors.onPrimary,
      disabledBackgroundColor: destructive
          ? AppColors.error.withValues(alpha: 0.45)
          : disabledPrimaryFill,
      disabledForegroundColor: disabledPrimaryFg,
      shape: RoundedRectangleBorder(borderRadius: radius),
      animationDuration: AppMotion.press,
      splashFactory: InkRipple.splashFactory,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.transparent;
        }
        if (states.contains(WidgetState.pressed)) {
          return fillPressed.withValues(alpha: destructive ? 0.2 : 0.32);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return AppColors.onPrimary.withValues(alpha: 0.12);
        }
        return null;
      }),
    );
  }

  static ButtonStyle filledLoading({
    required Size minimumSize,
    required EdgeInsetsGeometry padding,
    required TextStyle textStyle,
    BorderRadius? borderRadius,
    VisualDensity? visualDensity,
    MaterialTapTargetSize tapTargetSize = MaterialTapTargetSize.shrinkWrap,
    bool destructive = false,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.md);
    final fill = destructive ? AppColors.error : AppColors.primaryBlue;
    return FilledButton.styleFrom(
      minimumSize: minimumSize,
      padding: padding,
      tapTargetSize: tapTargetSize,
      visualDensity: visualDensity,
      textStyle: textStyle,
      backgroundColor: fill,
      foregroundColor: AppColors.onPrimary,
      disabledBackgroundColor: fill,
      disabledForegroundColor: AppColors.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: radius),
      animationDuration: AppMotion.press,
      splashFactory: InkRipple.splashFactory,
    );
  }

  static ButtonStyle filledSecondary({
    required Size minimumSize,
    required EdgeInsetsGeometry padding,
    required TextStyle textStyle,
    BorderRadius? borderRadius,
    VisualDensity? visualDensity,
    MaterialTapTargetSize tapTargetSize = MaterialTapTargetSize.shrinkWrap,
    bool destructive = false,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.md);
    final fill = destructive
        ? AppColors.error.withValues(alpha: 0.12)
        : AppColors.secondaryBlue;
    final fg = destructive ? AppColors.error : AppColors.primaryBlue;
    final fillDisabled = destructive
        ? AppColors.error.withValues(alpha: 0.06)
        : AppColors.secondaryBlue.withValues(alpha: 0.45);
    return FilledButton.styleFrom(
      minimumSize: minimumSize,
      padding: padding,
      tapTargetSize: tapTargetSize,
      visualDensity: visualDensity,
      textStyle: textStyle,
      backgroundColor: fill,
      foregroundColor: fg,
      disabledBackgroundColor: fillDisabled,
      disabledForegroundColor: disabledSecondaryFg,
      shape: RoundedRectangleBorder(borderRadius: radius),
      animationDuration: AppMotion.press,
      splashFactory: InkRipple.splashFactory,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppColors.transparent;
        }
        if (states.contains(WidgetState.pressed)) {
          return destructive
              ? AppColors.error.withValues(alpha: 0.16)
              : AppColors.primaryBlue.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return destructive
              ? AppColors.error.withValues(alpha: 0.08)
              : AppColors.primaryBlue.withValues(alpha: 0.08);
        }
        return null;
      }),
    );
  }
}

VoidCallback? _withLightHaptic(BuildContext context, VoidCallback? onPressed) {
  if (onPressed == null) return null;
  return () {
    AppFeedback.light(context);
    onPressed();
  };
}

// CTA-only press scale (0.97). Not for list rows or chips.
class _CtaPressScale extends StatefulWidget {
  const _CtaPressScale({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_CtaPressScale> createState() => _CtaPressScaleState();
}

class _CtaPressScaleState extends State<_CtaPressScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = (!reduceMotion && widget.enabled && _pressed)
        ? AppMotion.pressScale
        : 1.0;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: scale,
        duration: AppMotion.press,
        curve: AppMotion.emphasized,
        child: widget.child,
      ),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.applyTitleCase = false,
    this.loading = false,
    this.iconTrailing = false,
    this.fullWidth = true,
    this.compact = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool applyTitleCase;
  final bool loading;
  final bool iconTrailing;
  final bool fullWidth;
  final bool compact;
  final bool destructive;

  String get _displayLabel =>
      applyTitleCase ? formatTitleCaseWords(label) : label;

  @override
  Widget build(BuildContext context) {
    final effectiveOn = loading ? null : onPressed;
    final hapticOn = _withLightHaptic(context, effectiveOn);
    final minSize = Size(
      fullWidth ? double.infinity : 0,
      compact ? 32 : AppSpacing.primaryButtonMinHeight,
    );
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 0)
        : AppButtonStyleTokens.symmetricPadding;
    final textStyle = compact
        ? AppTypography.buttonDense
        : AppTypography.button;
    final radius = BorderRadius.circular(compact ? AppRadius.sm : AppRadius.md);
    final spinnerSize = compact ? 18.0 : 24.0;

    if (loading) {
      return FilledButton(
        onPressed: null,
        style: AppButtonStyleTokens.filledLoading(
          minimumSize: minSize,
          padding: padding,
          textStyle: textStyle,
          borderRadius: radius,
          visualDensity: compact ? VisualDensity.compact : null,
          destructive: destructive,
        ),
        child: SizedBox(
          width: spinnerSize,
          height: spinnerSize,
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.onPrimary,
          ),
        ),
      );
    }

    final style = AppButtonStyleTokens.filled(
      minimumSize: minSize,
      padding: padding,
      textStyle: textStyle,
      borderRadius: radius,
      visualDensity: compact ? VisualDensity.compact : null,
      destructive: destructive,
    );

    final Widget button;
    if (icon != null && iconTrailing) {
      button = FilledButton(
        onPressed: hapticOn,
        style: style,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Text(
              _displayLabel,
              style: textStyle.copyWith(color: AppColors.onPrimary),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(icon, size: compact ? 18 : 22, color: AppColors.onPrimary),
          ],
        ),
      );
    } else if (icon == null) {
      button = FilledButton(
        onPressed: hapticOn,
        style: style,
        child: Text(_displayLabel),
      );
    } else {
      button = FilledButton.icon(
        onPressed: hapticOn,
        style: style,
        icon: Icon(icon, size: 18),
        label: Text(_displayLabel),
      );
    }

    return _CtaPressScale(enabled: hapticOn != null, child: button);
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.applyTitleCase = false,
    this.loading = false,
    this.fullWidth = true,
    this.compact = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool applyTitleCase;
  final bool loading;
  final bool fullWidth;
  final bool compact;
  final bool destructive;

  String get _displayLabel =>
      applyTitleCase ? formatTitleCaseWords(label) : label;

  @override
  Widget build(BuildContext context) {
    final effectiveOn = loading ? null : onPressed;
    final hapticOn = _withLightHaptic(context, effectiveOn);
    final enabled = hapticOn != null;
    final minSize = Size(
      fullWidth ? double.infinity : 0,
      compact ? 32 : AppSpacing.primaryButtonMinHeight,
    );
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 0)
        : AppButtonStyleTokens.symmetricPadding;
    final textStyle = compact
        ? AppTypography.buttonDense
        : AppTypography.button;
    final radius = BorderRadius.circular(compact ? AppRadius.sm : AppRadius.md);
    final style = AppButtonStyleTokens.filledSecondary(
      minimumSize: minSize,
      padding: padding,
      textStyle: textStyle,
      borderRadius: radius,
      visualDensity: compact ? VisualDensity.compact : null,
      destructive: destructive,
    );
    final progressColor = destructive ? AppColors.error : AppColors.primaryBlue;
    final spinnerSize = compact ? 18.0 : 22.0;

    if (loading) {
      return FilledButton(
        onPressed: null,
        style: style,
        child: SizedBox(
          width: spinnerSize,
          height: spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: progressColor,
          ),
        ),
      );
    }

    return _CtaPressScale(
      enabled: enabled,
      child: icon == null
          ? FilledButton(
              onPressed: hapticOn,
              style: style,
              child: Text(_displayLabel),
            )
          : FilledButton.icon(
              onPressed: hapticOn,
              style: style,
              icon: Icon(icon, size: compact ? 16 : 18),
              label: Text(_displayLabel),
            ),
    );
  }
}
