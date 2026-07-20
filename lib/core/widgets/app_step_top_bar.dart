import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_top_bar.dart';

// Like AppTopBar but with step dots (create listing flow)
class AppStepTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppStepTopBar({
    super.key,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    this.showBack = true,
    this.onBack,
    this.actions,
  });

  final String title;
  final int currentStep;
  final int totalSteps;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  static const double _toolbarHeight = AppTopBar.kToolbarHeight;

  @override
  Widget build(BuildContext context) {
    final displayTitle = AppTopBar.formatTitle(title);
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: false,
      toolbarHeight: _toolbarHeight,
      foregroundColor: AppColors.black,
      leading: showBack
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.primaryBlue,
              ),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : null,
      actions: actions,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayTitle,
                style: AppTypography.navTitle.copyWith(color: AppColors.black),
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StepBadgeColumn(currentStep: currentStep, totalSteps: totalSteps),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(_toolbarHeight);
}

// --- Private: step indicator (styles live here, not in feature screens) ---

class _StepBadgeColumn extends StatelessWidget {
  const _StepBadgeColumn({required this.currentStep, required this.totalSteps});

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.primaryBlue,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$currentStep',
            style: AppTypography.captionStrong.copyWith(
              color: AppColors.onPrimary,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Step $currentStep of $totalSteps',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
