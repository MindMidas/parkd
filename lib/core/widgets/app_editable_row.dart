import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

/// Reusable row for edit screens: label (uppercase caption), value text, and an optional Edit button.
/// Use for Photo, Price, or any single label+value+action row.
class AppEditableRow extends StatelessWidget {
  const AppEditableRow({
    super.key,
    required this.label,
    required this.value,
    this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback? onEdit;

  static const double _editButtonWidth = 92;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(value, style: AppTypography.body),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: _editButtonWidth,
            child: AppPrimaryButton(
              label: 'Edit',
              onPressed: onEdit,
            ),
          ),
        ],
      ),
    );
  }
}
