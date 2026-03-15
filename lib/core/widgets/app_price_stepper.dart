import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Reusable row: label on the left, stepper (minus / value / plus) on the right.
/// Use for hourly/daily price or any numeric selector. Circular light blue buttons.
class AppPriceStepper extends StatelessWidget {
  const AppPriceStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
    this.step = 1,
    this.prefix = '\$',
  });

  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final num min;
  final num max;
  final num step;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final canDecrement = value > min;
    final canIncrement = value < max;
    final displayValue = value is int ? value.toString() : value.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepperButton(
                icon: Icons.remove,
                onPressed: canDecrement
                    ? () => onChanged((value - step).clamp(min, max))
                    : null,
              ),
              SizedBox(
                width: 56,
                child: Center(
                  child: Text(
                    '$prefix$displayValue',
                    style: AppTypography.body,
                  ),
                ),
              ),
              _StepperButton(
                icon: Icons.add,
                onPressed: canIncrement
                    ? () => onChanged((value + step).clamp(min, max))
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, this.onPressed});

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
                : AppColors.secondaryGrey.withValues(alpha: 0.2),
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
