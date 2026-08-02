import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

enum AppPageStatusKind { loading, empty, error }

// Shared loading / empty / error body for list hubs and detail screens.
class AppPageStatus extends StatelessWidget {
  const AppPageStatus({
    super.key,
    required this.kind,
    this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  const AppPageStatus.loading({super.key})
    : kind = AppPageStatusKind.loading,
      title = null,
      message = null,
      icon = null,
      actionLabel = null,
      onAction = null;

  // Muted empty-state text without a default icon.
  const AppPageStatus.empty({
    super.key,
    required this.title,
    this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
  }) : kind = AppPageStatusKind.empty;

  const AppPageStatus.error({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Check your connection and try again.',
    this.icon = Icons.cloud_off_outlined,
    this.actionLabel,
    this.onAction,
  }) : kind = AppPageStatusKind.error;

  final AppPageStatusKind kind;
  final String? title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    if (kind == AppPageStatusKind.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isEmpty = kind == AppPageStatusKind.empty;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: isEmpty ? AppSpacing.xl : AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: isEmpty ? 28 : 44,
                color: isEmpty
                    ? AppColors.iconGrey.withValues(alpha: 0.55)
                    : AppColors.iconGrey,
              ),
              SizedBox(height: isEmpty ? AppSpacing.sm : AppSpacing.md),
            ],
            if (title != null) ...[
              Text(
                title!,
                style: isEmpty
                    ? AppTypography.bodyMuted
                    : AppTypography.hubTitle,
                textAlign: TextAlign.center,
              ),
              if (message != null) const SizedBox(height: AppSpacing.xs),
            ],
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
