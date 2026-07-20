import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Report $targetLabel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reports are private and reviewed for this portfolio demo.',
                  style: AppTypography.bodyMuted,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  items: _reportReasons.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: submitting
                      ? null
                      : (value) {
                          if (value != null) reason = value;
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: detailsController,
                  enabled: !submitting,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Details (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
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
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  } finally {
    detailsController.dispose();
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
