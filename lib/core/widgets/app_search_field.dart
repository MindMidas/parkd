import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    this.hintText = 'Search',
    this.onChanged,
    this.controller,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondary,
        ),

        // ── Filter button (optional) ──────────────────────────────────────
        if (widget.showFilterButton) ...[
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.iconGrey.withValues(alpha: 0.2),
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.iconGrey,
                size: 20,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
