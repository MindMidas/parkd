import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/notifications_providers.dart';

enum _ChatNotificationAction { markUnread, toggleMute }

Future<void> showChatNotificationOptionsSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String reservationId,
  required bool isMuted,
}) async {
  final action = await AppModalSheet.show<_ChatNotificationAction>(
    context: context,
    builder: (sheetContext) => AppModalSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Messages', style: AppTypography.hubTitle),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.mark_email_unread_outlined,
              color: AppColors.primaryBlue,
            ),
            title: Text('Mark as unread', style: AppTypography.bodyStrong),
            subtitle: Text(
              'Keep a reminder until you open this chat again.',
              style: AppTypography.caption,
            ),
            onTap: () => Navigator.of(
              sheetContext,
            ).pop(_ChatNotificationAction.markUnread),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              isMuted
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: AppColors.primaryBlue,
            ),
            title: Text(
              isMuted ? 'Unmute messages' : 'Mute messages',
              style: AppTypography.bodyStrong,
            ),
            subtitle: Text(
              isMuted
                  ? 'Receive notifications from this chat again.'
                  : 'Messages still arrive, but notifications are silenced.',
              style: AppTypography.caption,
            ),
            onTap: () => Navigator.of(
              sheetContext,
            ).pop(_ChatNotificationAction.toggleMute),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
  if (action == null) return;
  try {
    final remote = ref.read(notificationsRemoteProvider);
    final ok = switch (action) {
      _ChatNotificationAction.markUnread =>
        await remote.markReservationNotificationsUnread(reservationId),
      _ChatNotificationAction.toggleMute =>
        await remote.setReservationMessagesMuted(
          reservationId: reservationId,
          muted: !isMuted,
        ),
    };
    if (!context.mounted) return;
    if (!ok) return;
    ref.invalidate(myNotificationFeedProvider);
  } catch (_) {}
}
