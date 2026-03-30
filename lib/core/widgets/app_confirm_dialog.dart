import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

// Card-style confirm dialog (Cancel / Confirm)
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.cancelLabel = 'Cancel',
    this.confirmLabel = 'Confirm',
    this.confirmDestructive = false,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final bool confirmDestructive;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.hubTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppSecondaryButton(
                    label: cancelLabel,
                    onPressed: onCancel,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: confirmDestructive
                      ? AppSecondaryButton(
                          label: confirmLabel,
                          onPressed: onConfirm,
                          destructive: true,
                        )
                      : AppPrimaryButton(
                          label: confirmLabel,
                          onPressed: onConfirm,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
