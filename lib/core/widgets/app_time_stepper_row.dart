import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Row with label, time value, and minus/plus circular buttons (blue, white icons).
/// Use [labelWidth] when stacking multiple rows so the +/- controls align (e.g. labelWidth: 100).
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
  });

  final String label;
  final String value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final bool canDecrement;
  final bool canIncrement;
  /// Fixed width for the label so multiple rows align their +/- controls.
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(
      label,
      style: AppTypography.body.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          if (labelWidth != null)
            SizedBox(
              width: labelWidth,
              child: labelWidget,
            )
          else
            labelWidget,
          const SizedBox(width: AppSpacing.md),
          _CircleButton(
            icon: Icons.remove,
            onPressed: canDecrement ? onDecrement : null,
          ),
          SizedBox(
            width: 80,
            child: Center(
              child: Text(value, style: AppTypography.body),
            ),
          ),
          _CircleButton(
            icon: Icons.add,
            onPressed: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primaryBlue
                : AppColors.secondaryGrey.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
