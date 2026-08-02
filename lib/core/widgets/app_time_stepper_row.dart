import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Label, time, and step controls for stacked rows.
class AppTimeStepperRow extends StatelessWidget {
  const AppTimeStepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.canDecrement = true,
    this.canIncrement = true,
    this.labelWidth,
    this.labelStyle,
  });

  final String label;
  final String value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool canDecrement;
  final bool canIncrement;
  final double? labelWidth;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: labelStyle ?? AppTypography.bodyStrong,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          if (labelWidth != null)
            SizedBox(width: labelWidth, child: labelWidget)
          else
            labelWidget,
          const SizedBox(width: AppSpacing.md),
          _HoldRepeatStepButton(
            icon: Icons.remove,
            onPressed: canDecrement ? onDecrement : null,
          ),
          SizedBox(
            width: 100,
            child: Center(
              child: Text(
                value,
                style: AppTypography.body,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          _HoldRepeatStepButton(
            icon: Icons.add,
            onPressed: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

// Tap once or hold to fire repeatedly
class _HoldRepeatStepButton extends StatefulWidget {
  const _HoldRepeatStepButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_HoldRepeatStepButton> createState() => _HoldRepeatStepButtonState();
}

class _HoldRepeatStepButtonState extends State<_HoldRepeatStepButton> {
  Timer? _holdDelay;
  Timer? _repeat;

  void _cancelTimers() {
    _holdDelay?.cancel();
    _holdDelay = null;
    _repeat?.cancel();
    _repeat = null;
  }

  void _onPointerDown() {
    if (widget.onPressed == null) return;
    _cancelTimers();
    _holdDelay = Timer(const Duration(milliseconds: 380), () {
      _holdDelay = null;
      widget.onPressed!();
      _repeat = Timer.periodic(const Duration(milliseconds: 70), (_) {
        widget.onPressed!();
      });
    });
  }

  void _onPointerUpOrCancel() {
    if (widget.onPressed == null) return;
    final hadRepeat = _repeat != null;
    _holdDelay?.cancel();
    _holdDelay = null;
    _repeat?.cancel();
    _repeat = null;
    if (!hadRepeat) {
      widget.onPressed!();
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _onPointerDown(),
      onPointerUp: (_) => _onPointerUpOrCancel(),
      onPointerCancel: (_) => _onPointerUpOrCancel(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primaryBlue
              : AppColors.secondaryGrey.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.icon,
          size: 20,
          color: enabled ? AppColors.onPrimary : AppColors.textSecondary,
        ),
      ),
    );
  }
}
