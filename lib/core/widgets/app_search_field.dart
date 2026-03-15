import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondary,
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.iconGrey),
        filled: true,
        fillColor: AppColors.secondaryBlue.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

