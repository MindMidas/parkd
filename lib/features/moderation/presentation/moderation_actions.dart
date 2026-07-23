import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_ink.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/moderation_providers.dart';

const Map<String, String> _reportReasons = {
  'spam': 'Spam or misleading',
  'harassment': 'Harassment or bullying',
  'fraud': 'Fraud or scam',
  'inappropriate': 'Inappropriate content',
  'safety': 'Safety concern',
  'other': 'Other',
};

Future<void> showParkdReportDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String targetType,
  required String targetId,
  required String targetLabel,
}) async {
  var reason = _reportReasons.keys.first;
  final detailsController = TextEditingController();
  var submitting = false;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialogSurface(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Report $targetLabel',
                  style: AppTypography.hubTitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Reports are private and reviewed by Parkd moderators.',
                  style: AppTypography.bodyMuted,
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Reason', style: AppTypography.captionStrong),
                const SizedBox(height: AppSpacing.xs),
                for (final entry in _reportReasons.entries) ...[
                  _ReportReasonRow(
                    label: entry.value,
                    selected: reason == entry.key,
                    enabled: !submitting,
                    onTap: () => setDialogState(() => reason = entry.key),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: detailsController,
                  enabled: !submitting,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                  style: AppTypography.body,
                  decoration: InputDecoration(
                    labelText: 'Details (optional)',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: AppSecondaryButton(
                        label: 'Cancel',
                        onPressed: submitting
                            ? null
                            : () => Navigator.of(dialogContext).pop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppPrimaryButton(
                        label: 'Submit report',
                        loading: submitting,
                        onPressed: submitting
                            ? null
                            : () async {
                                setDialogState(() => submitting = true);
                                try {
                                  await ref
                                      .read(moderationRepositoryProvider)
                                      .submitReport(
                                        targetType: targetType,
                                        targetId: targetId,
                                        reason: reason,
                                        details: detailsController.text,
                                      );
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).pop();
                                  if (context.mounted) {
                                    AppMessenger.showSuccess(
                                      context,
                                      'Report submitted. Thank you for helping keep Parkd safe.',
                                    );
                                  }
                                } catch (_) {
                                  if (!dialogContext.mounted) return;
                                  setDialogState(() => submitting = false);
                                  AppMessenger.showError(
                                    dialogContext,
                                    'Could not submit the report. Try again.',
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    detailsController.dispose();
  }
}

class _ReportReasonRow extends StatelessWidget {
  const _ReportReasonRow({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.secondaryBlue.withValues(alpha: 0.65)
          : AppColors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppInk.splash,
        highlightColor: AppInk.highlight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: AppTypography.body),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 20,
                color: selected
                    ? AppColors.primaryBlue
                    : AppColors.secondaryGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmAndBlockParkdUser({
  required BuildContext context,
  required WidgetRef ref,
  required String userId,
  required String displayName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppConfirmDialog(
      title: 'Block $displayName?',
      message:
          'You will no longer see each other’s public listings or profiles, '
          'and messaging will stop. You can contact support to reverse this.',
      confirmLabel: 'Block user',
      onCancel: () => Navigator.of(dialogContext).pop(false),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await ref
        .read(moderationRepositoryProvider)
        .setUserBlocked(userId: userId, blocked: true);
    if (context.mounted) {
      AppMessenger.showSuccess(context, '$displayName has been blocked.');
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      AppMessenger.showError(context, 'Could not block this user. Try again.');
    }
    return false;
  }
}
