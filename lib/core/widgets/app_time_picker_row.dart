import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Tappable row with a bold label, a date/time value string, and a dropdown arrow.
/// Used for "Start time" / "End time" rows.
class AppTimePickerRow extends StatelessWidget {
  const AppTimePickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.labelWidth = 80,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(value, style: AppTypography.body),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}
