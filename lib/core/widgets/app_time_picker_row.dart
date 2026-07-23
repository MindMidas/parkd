import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Tappable "Start time" style row (label + value + chevron)
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
            child: Text(label, style: AppTypography.bodyStrong),
          ),
          const SizedBox(width: AppSpacing.md),
          const Spacer(),
          Text(value, style: AppTypography.body),
          const SizedBox(width: AppSpacing.xs),
          const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBlue),
        ],
      ),
    );
  }
}
