import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Scrollable terms/policy text box with a checkbox + label below it.
class AppTermsCheckbox extends StatelessWidget {
  const AppTermsCheckbox({
    super.key,
    required this.heading,
    required this.termsText,
    required this.checkboxLabel,
    required this.value,
    required this.onChanged,
    this.termsBoxHeight = 100,
  });

  final String heading;
  final String termsText;
  final String checkboxLabel;
  final bool value;
  final ValueChanged<bool> onChanged;
  final double termsBoxHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.secondaryGrey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          height: termsBoxHeight,
          child: SingleChildScrollView(
            child: Text(
              termsText,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!value),
                child: Text(checkboxLabel, style: AppTypography.body),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
