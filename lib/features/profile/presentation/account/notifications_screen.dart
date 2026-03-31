import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/notification_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/notifications_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(myNotificationsProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: 'Notifications',
        showBack: true,
        actions: [
          TextButton(
            onPressed: () async {
              final uid = ref.read(currentSessionProvider)?.user.id;
              if (uid == null) return;
              await ref.read(notificationsRemoteProvider).markAllRead(uid);
              ref.invalidate(myNotificationsProvider);
              ref.invalidate(myUnreadNotificationsCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Could not load notifications')),
          data: (rows) {
            if (rows.isEmpty) {
              return Center(
                child: Text(
                  'No notifications yet',
                  style: AppTypography.caption,
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final row = rows[index];
                return _NotificationTile(row: row);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.row});

  final NotificationRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamp = DateFormat('MMM d, h:mm a').format(row.createdAt.toLocal());
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      title: Text(
        row.title,
        style: row.isRead ? AppTypography.body : AppTypography.hubTitle,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('${row.body}\n$stamp', style: AppTypography.caption),
      ),
      isThreeLine: true,
      trailing: row.isRead
          ? null
          : const Icon(
              Icons.fiber_manual_record,
              size: 10,
              color: AppColors.primaryBlue,
            ),
      onTap: () async {
        if (!row.isRead) {
          await ref.read(notificationsRemoteProvider).markRead(row.id);
          ref.invalidate(myNotificationsProvider);
          ref.invalidate(myUnreadNotificationsCountProvider);
        }
      },
    );
  }
}
