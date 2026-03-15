import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Horizontal divider with centered text (e.g. "Scheduled time slots"). Reusable for section breaks.
class AppSectionDividerTitle extends StatelessWidget {
  const AppSectionDividerTitle(
    this.text, {
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.secondaryGrey.withValues(alpha: 0.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.secondaryGrey.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
