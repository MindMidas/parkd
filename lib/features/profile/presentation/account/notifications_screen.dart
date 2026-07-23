import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/notification_row.dart';
import '../../../../core/supabase/notifications_remote.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_ink.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../reservations/presentation/notification_conversation_route_screen.dart';
import '../../providers/notifications_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<NotificationRow> _older = [];
  bool _loadingOlder = false;
  bool _hasMore = true;

  List<NotificationRow> _combined(List<NotificationRow> latest) {
    final byId = <String, NotificationRow>{
      for (final row in [...latest, ..._older]) row.id: row,
    };
    final rows = byId.values.toList(growable: false);
    rows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Future<void> _loadOlder(List<NotificationRow> latest) async {
    if (_loadingOlder || !_hasMore) return;
    final userId = ref.read(currentSessionProvider)?.user.id;
    if (userId == null) return;
    final visible = _combined(latest);
    if (visible.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await ref
          .read(notificationsRemoteProvider)
          .listPage(userId: userId, before: visible.last.createdAt);
      if (!mounted) return;
      setState(() {
        _older.addAll(page);
        _hasMore = page.length == NotificationsRemote.pageSize;
      });
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Could not load older notifications.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationsRemoteProvider).markAllRead();
      if (mounted) {
        setState(_older.clear);
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Could not update notifications.');
      }
    }
  }

  Future<void> _delete(NotificationRow row) async {
    try {
      final deleted = await ref
          .read(notificationsRemoteProvider)
          .deleteNotification(row.id);
      if (!deleted) throw StateError('Notification was not deleted');
      if (mounted) {
        setState(() => _older.removeWhere((item) => item.id == row.id));
      }
    } catch (_) {
      if (mounted) {
        AppMessenger.showError(context, 'Could not delete notification.');
      }
      rethrow;
    }
  }

  Future<void> _open(NotificationRow row) async {
    try {
      if (!row.isRead) {
        await ref.read(notificationsRemoteProvider).markRead(row.id);
      }
    } catch (_) {
      // Navigation remains useful if a transient read-receipt update fails.
    }
    if (!mounted) return;

    final reservationId = row.reservationId;
    if (row.type == ParkdNotificationType.messageReceived &&
        reservationId != null) {
      context.push(reservationMessagesLocation(reservationId));
      return;
    }
    final tab = row.hub == NotificationHub.reservations
        ? 'reservations'
        : 'hosting';
    context.go('/home?tab=$tab');
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(myNotificationFeedProvider);
    final unread = feed.value?.unread.total ?? 0;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: 'Notifications',
        showBack: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppPrimaryButton(
              key: const Key('notifications_mark_all_read'),
              label: 'Mark all read',
              fullWidth: false,
              compact: true,
              onPressed: unread == 0 ? null : _markAllRead,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: feed.when(
          loading: () => const AppPageStatus.loading(),
          error: (_, _) => AppPageStatus.error(
            title: 'Notifications unavailable',
            message: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(myNotificationFeedProvider),
          ),
          data: (snapshot) {
            final rows = _combined(snapshot.latest);
            if (rows.isEmpty) {
              return const AppPageStatus.empty(
                title: 'No notifications yet',
                message: 'Booking, review, and message updates appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              itemCount: rows.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                if (index == rows.length) {
                  return Center(
                    child: AppSecondaryButton(
                      key: const Key('notifications_load_older'),
                      label: 'Load older',
                      icon: Icons.expand_more_rounded,
                      fullWidth: false,
                      compact: true,
                      loading: _loadingOlder,
                      onPressed: _loadingOlder
                          ? null
                          : () => _loadOlder(snapshot.latest),
                    ),
                  );
                }
                final row = rows[index];
                return Dismissible(
                  key: ValueKey('notification_${row.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    try {
                      await _delete(row);
                      return true;
                    } catch (_) {
                      return false;
                    }
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  child: _NotificationCard(row: row, onTap: () => _open(row)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.row, required this.onTap});

  final NotificationRow row;
  final VoidCallback onTap;

  IconData get _icon => switch (row.type) {
    ParkdNotificationType.reservationConfirmed => Icons.event_available_rounded,
    ParkdNotificationType.messageReceived => Icons.chat_bubble_outline_rounded,
    ParkdNotificationType.reviewReceived => Icons.star_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: row.isRead
          ? AppColors.surface
          : AppColors.secondaryBlue.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: row.isRead ? AppColors.secondaryGrey : AppColors.primaryBlue,
          width: row.isRead ? 1 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppInk.splashSoft,
        highlightColor: AppInk.highlight,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(_icon, color: AppColors.primaryBlue),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title, style: AppTypography.bodyStrong),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(row.body, style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      DateFormat(
                        'MMM d, h:mm a',
                      ).format(row.createdAt.toLocal()),
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.iconGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
