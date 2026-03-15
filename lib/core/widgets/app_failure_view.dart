import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

/// Reusable failure/error layout: X icon, title, message, and action button.
/// Same structure as [AppSuccessView] but with error styling for failed flows.
class AppFailureView extends StatelessWidget {
  const AppFailureView({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.buttonLabel = 'Close',
    required this.onClose,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: AppTypography.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: AppPrimaryButton(
              label: buttonLabel,
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}
