import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
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
            return ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final stamp =
                    DateFormat('MMM d, h:mm a').format(row.createdAt.toLocal());
                final icon = switch (row.type) {
                  'reservation_confirmed' => Icons.event_available_rounded,
                  'message_received' => Icons.chat_bubble_outline_rounded,
                  'review_received' => Icons.star_outline_rounded,
                  _ => Icons.notifications_none_rounded,
                };
                final senderName = row.dataJson['sender_name'] is String
                    ? (row.dataJson['sender_name'] as String).trim()
                    : '';
                final title = row.type == 'message_received' &&
                        senderName.isNotEmpty
                    ? 'New message from $senderName'
                    : row.title;
                final subtitle = row.isRead ? row.body : 'NEW • ${row.body}';
                return AppMenuRow(
                  title: title,
                  subtitle: subtitle,
                  tertiary: stamp,
                  leadingIcon: icon,
                  showTopDivider: true,
                  showBottomDivider: index == rows.length - 1,
                  onTap: () async {
                    if (!row.isRead) {
                      await ref.read(notificationsRemoteProvider).markRead(row.id);
                      ref.invalidate(myNotificationsProvider);
                      ref.invalidate(myUnreadNotificationsCountProvider);
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
