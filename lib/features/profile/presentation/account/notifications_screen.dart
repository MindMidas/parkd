import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/go_router_provider.dart';
import '../../../../app/message_notification_navigation.dart';
import '../../../../core/messaging/app_messenger.dart';
import '../../../../core/models/notification_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/profile_avatar_image_provider.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../reservations/providers/reservations_providers.dart';
import '../../providers/notifications_providers.dart';
import '../../providers/profile_providers.dart';

const double _kNotificationThumbSize = 48;

void _invalidateNotificationFeed(ProviderContainer container) {
  container.invalidate(myNotificationsProvider);
  container.invalidate(myUnreadNotificationsCountProvider);
  container.invalidate(notificationNavHubCountsProvider);
}

TextStyle _notificationTimestampStyle() => AppTypography.caption.copyWith(
      color: AppColors.textSecondary,
      fontSize: 12,
      height: 1.2,
    );

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
              if (!context.mounted) return;
              final container = ProviderScope.containerOf(context, listen: false);
              await container.read(notificationsRemoteProvider).markAllRead(uid);
              _invalidateNotificationFeed(container);
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                return _NotificationDismissibleCard(row: rows[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationDismissibleCard extends ConsumerWidget {
  const _NotificationDismissibleCard({required this.row});

  final NotificationRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey<String>(row.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (direction != DismissDirection.endToStart) return false;
        try {
          await ref.read(notificationsRemoteProvider).deleteNotification(row.id);
          if (!context.mounted) return false;
          _invalidateNotificationFeed(ProviderScope.containerOf(context, listen: false));
          return true;
        } catch (_) {
          if (context.mounted) {
            AppMessenger.showError(context, 'Could not delete notification.');
          }
          return false;
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.onPrimary),
      ),
      child: _NotificationCard(row: row),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.row});

  final NotificationRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stamp = DateFormat('MMM d, h:mm a').format(row.createdAt.toLocal());
    final typeIcon = switch (row.type) {
      'reservation_confirmed' => Icons.event_available_rounded,
      'message_received' => Icons.chat_bubble_outline_rounded,
      'review_received' => Icons.star_outline_rounded,
      _ => Icons.notifications_none_rounded,
    };

    final rawSenderId = row.dataJson['sender_id'];
    final String? messageSenderId = rawSenderId is String
        ? (rawSenderId.trim().isEmpty ? null : rawSenderId.trim())
        : null;

    final unread = !row.isRead;
    final borderColor = unread
        ? AppColors.primaryBlue
        : AppColors.iconGrey.withValues(alpha: 0.28);
    final borderWidth = unread ? 1.5 : 1.0;

    final Widget leading;
    if (row.type == 'message_received') {
      leading = SizedBox(
        width: _kNotificationThumbSize,
        height: _kNotificationThumbSize,
        child: Center(child: _NotificationMessageAvatar(row: row)),
      );
    } else if (row.type == 'reservation_confirmed') {
      leading = _BookingListingThumb(row: row);
    } else {
      leading = SizedBox(
        width: _kNotificationThumbSize,
        height: _kNotificationThumbSize,
        child: Center(
          child: Icon(
            typeIcon,
            size: 24,
            color: unread ? AppColors.primaryBlue : AppColors.iconGrey,
          ),
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _onTap(context, ref),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: borderWidth),
            color: unread
                ? AppColors.secondaryBlue.withValues(alpha: 0.45)
                : AppColors.surface,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _NotificationTextBlock(
                  row: row,
                  messageSenderId: messageSenderId,
                  stamp: stamp,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.iconGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Only mark read when the user actually taps the row, not when opening the inbox.
  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    final container = ProviderScope.containerOf(context, listen: false);

    Future<void> consumeTap() async {
      if (row.isRead) return;
      try {
        await container.read(notificationsRemoteProvider).markRead(row.id);
        _invalidateNotificationFeed(container);
      } catch (_) {}
    }

    try {
      if (row.type == 'reservation_confirmed') {
        await tryNavigateReservationConfirmedDeepLink(ref, row);
        return;
      }
      if (row.type == 'message_received') {
        final deepLinked =
            await tryNavigateMessageNotificationDeepLink(ref, row);
        if (deepLinked) return;
        final reservationId = row.dataJson['reservation_id'] is String
            ? (row.dataJson['reservation_id'] as String).trim()
            : '';
        final sid = reservationId.isNotEmpty
            ? reservationId
            : row.sourceEntityId?.trim() ?? '';
        if (sid.isEmpty) return;
        final conversationId = row.dataJson['conversation_id'] is String
            ? (row.dataJson['conversation_id'] as String).trim()
            : null;
        var peerName = 'Messages';
        final senderKey = row.dataJson['sender_id'];
        if (senderKey is String && senderKey.trim().isNotEmpty) {
          final p = await ref
              .read(profileRepositoryProvider)
              .getProfile(senderKey.trim());
          final n = p?.displayName.trim() ?? '';
          if (n.isNotEmpty) peerName = n;
        }
        if (!context.mounted) return;
        await ref.read(goRouterProvider).push<void>(
              '/trip-conversation',
              extra: <String, dynamic>{
                'reservationId': sid,
                if (conversationId != null && conversationId.isNotEmpty)
                  'conversationId': conversationId,
                'peerDisplayName': peerName,
              },
            );
        return;
      }
    } finally {
      await consumeTap();
    }
  }
}

class _BookingListingThumb extends ConsumerWidget {
  const _BookingListingThumb({required this.row});

  final NotificationRow row;

  static String? _str(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  static ImageProvider? _httpImage(String? url) {
    final u = url?.trim();
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) {
      return NetworkImage(u);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingId = _str(row.dataJson['listing_id']);
    ImageProvider? provider;
    if (listingId != null) {
      final listing = ref.watch(listingByIdProvider(listingId)).asData?.value;
      provider = _httpImage(listing?.heroPhotoUrl);
    }

    final radius = BorderRadius.circular(8);
    if (provider == null) {
      return SizedBox(
        width: _kNotificationThumbSize,
        height: _kNotificationThumbSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.secondaryBlue.withValues(alpha: 0.35),
            borderRadius: radius,
            border: Border.all(
              color: AppColors.iconGrey.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(
            Icons.local_parking_rounded,
            size: 26,
            color: !row.isRead ? AppColors.primaryBlue : AppColors.iconGrey,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: Image(
        image: provider,
        width: _kNotificationThumbSize,
        height: _kNotificationThumbSize,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => SizedBox(
          width: _kNotificationThumbSize,
          height: _kNotificationThumbSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.secondaryBlue.withValues(alpha: 0.35),
              borderRadius: radius,
            ),
            child: Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.iconGrey,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationMessageAvatar extends ConsumerWidget {
  const _NotificationMessageAvatar({required this.row});

  final NotificationRow row;

  static String? _str(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderId = _str(row.dataJson['sender_id']);
    ImageProvider? provider;
    if (senderId != null) {
      final prof = ref.watch(profileByUserIdProvider(senderId)).asData?.value;
      provider = profileAvatarImageProvider(prof);
    }

    if (provider == null) {
      return Icon(
        Icons.chat_bubble_outline_rounded,
        size: 22,
        color: !row.isRead ? AppColors.primaryBlue : AppColors.iconGrey,
      );
    }

    return ClipOval(
      child: Image(
        image: provider,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Icon(
          Icons.chat_bubble_outline_rounded,
          size: 22,
          color: !row.isRead ? AppColors.primaryBlue : AppColors.iconGrey,
        ),
      ),
    );
  }
}

class _NotificationTextBlock extends ConsumerWidget {
  const _NotificationTextBlock({
    required this.row,
    this.messageSenderId,
    required this.stamp,
  });

  final NotificationRow row;
  final String? messageSenderId;
  final String stamp;

  static String? _str(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  Widget _titleWithDateBelow(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyStrong.copyWith(
            color: AppColors.textPrimary,
            fontSize: 15,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          stamp,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _notificationTimestampStyle(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (row.type == 'message_received') {
      final preview = row.body.trim();
      var senderLabel = '';
      final sid = messageSenderId;
      if (sid != null) {
        final prof =
            ref.watch(profileByUserIdProvider(sid)).asData?.value;
        senderLabel = prof?.displayName.trim() ?? '';
      }
      final resId = _str(row.dataJson['reservation_id']);
      final cid = _str(row.dataJson['conversation_id']);
      final reservation = resId != null
          ? ref.watch(reservationByIdProvider(resId)).asData?.value
          : null;
      final conversation = cid != null
          ? ref.watch(conversationByIdProvider(cid)).asData?.value
          : null;
      final roleBracket = row.resolvedMessageSenderRoleBracket(
        reservationHostId: reservation?.hostId ?? conversation?.hostId,
        reservationDriverId: reservation?.driverId ?? conversation?.driverId,
      );
      final title =
          roleBracket != null ? 'New message $roleBracket' : 'New message';
      final fromLine = senderLabel.isNotEmpty
          ? 'from $senderLabel${preview.isNotEmpty ? ': $preview' : ''}'
          : preview;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _titleWithDateBelow(title),
          if (fromLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              fromLine,
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ],
        ],
      );
    }

    if (row.type == 'reservation_confirmed') {
      final driverId = _str(row.dataJson['driver_id']);
      var driverLabel = '';
      if (driverId != null) {
        final p = ref.watch(profileByUserIdProvider(driverId)).asData?.value;
        driverLabel = p?.displayName.trim() ?? '';
      }
      final who = driverLabel.isNotEmpty ? driverLabel : 'Someone';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _titleWithDateBelow('New booking'),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: AppTypography.bodySecondary.copyWith(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.25,
              ),
              children: [
                TextSpan(
                  text: who,
                  style: AppTypography.bodyStrong.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
                const TextSpan(text: ' completed payment'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      );
    }

    final headline = switch (row.type) {
      'review_received' => 'New review',
      _ => row.title.trim().isNotEmpty ? row.title : 'Notification',
    };
    final preview = row.body.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _titleWithDateBelow(headline),
        if (preview.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            preview,
            style: AppTypography.bodySecondary.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
