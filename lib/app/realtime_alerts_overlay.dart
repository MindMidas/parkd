import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/notification_row.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/widgets.dart';
import 'go_router_provider.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/profile/providers/notifications_providers.dart';

class RealtimeAlertsOverlay extends ConsumerStatefulWidget {
  const RealtimeAlertsOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RealtimeAlertsOverlay> createState() =>
      _RealtimeAlertsOverlayState();
}

class _RealtimeAlertsOverlayState extends ConsumerState<RealtimeAlertsOverlay> {
  final Set<String> _seenNotificationIds = <String>{};
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(currentSessionProvider, (previous, next) {
      final prevId = previous?.user.id;
      final nextId = next?.user.id;
      if (prevId != nextId) {
        _seenNotificationIds.clear();
        _hydrated = false;
      }
    });
    ref.listenManual<AsyncValue<List<NotificationRow>>>(
      myNotificationsProvider,
      (previous, next) {
        final rows = next.value;
        if (rows == null) return;
        if (!_hydrated) {
          _seenNotificationIds.addAll(rows.map((r) => r.id));
          _hydrated = true;
          return;
        }

        final newcomers = rows
            .where((r) => !_seenNotificationIds.contains(r.id))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        for (final n in newcomers) {
          _seenNotificationIds.add(n.id);
          _showPopup(n);
        }
      },
    );
  }

  void _showPopup(NotificationRow notification) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final style = _styleFor(notification.type);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        dismissDirection: DismissDirection.none,
        duration: const Duration(seconds: 4),
        content: Material(
          color: style.backgroundColor,
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openMessages(notification),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: _buildPopupBody(notification, style),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMessages(NotificationRow notification) async {
    if (!mounted) return;

    final conversationId =
        _valueAsString(notification.dataJson['conversation_id']);
    final reservationId =
        _valueAsString(notification.dataJson['reservation_id']) ??
        notification.sourceEntityId;

    if (reservationId == null || reservationId.isEmpty) {
      debugPrint('Missing reservationId');
      return;
    }

    final senderName =
        _valueAsString(notification.dataJson['sender_name']);

    try {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final uid = ref.read(currentSessionProvider)?.user.id;
      if (uid != null) {
        await ref.read(notificationsRemoteProvider).markRead(notification.id);
      }

      if (!mounted) return;

      await ref.read(goRouterProvider).push<void>(
            '/trip-conversation',
            extra: <String, dynamic>{
              'reservationId': reservationId,
              'conversationId': conversationId,
              'peerDisplayName': senderName ?? 'Messages',
            },
          );
    } catch (e, stack) {
      debugPrint('Navigation error: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Widget _buildPopupBody(NotificationRow n, _PopupStyle style) {
    if (n.type == 'message_received') {
      final senderName =
          _valueAsString(n.dataJson['sender_name']) ?? 'Someone';
      final avatarUrl = _valueAsString(n.dataJson['sender_avatar_url']);
      final preview = n.body.trim();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppMenuProfileAvatar(
            imageProvider: _networkAvatarImageProvider(avatarUrl),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Open',
            style: TextStyle(
              color: AppColors.onPrimary.withValues(alpha: 0.95),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(style.icon, color: AppColors.onPrimary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            style.text(n),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.onPrimary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Open',
          style: TextStyle(
            color: AppColors.onPrimary.withValues(alpha: 0.95),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  ImageProvider? _networkAvatarImageProvider(String? url) {
    final u = url?.trim();
    if (u == null || u.isEmpty) return null;
    if (u.startsWith('http://') || u.startsWith('https://')) {
      return NetworkImage(u);
    }
    return null;
  }

  String? _valueAsString(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  _PopupStyle _styleFor(String type) {
    switch (type) {
      case 'reservation_confirmed':
        return _PopupStyle(
          backgroundColor: AppColors.primaryBlue,
          icon: Icons.event_available_rounded,
          text: (n) => 'Booking confirmed: ${n.body}',
        );
      case 'message_received':
        return _PopupStyle(
          backgroundColor: AppColors.success,
          icon: Icons.chat_bubble_rounded,
          text: (n) => 'New message: ${n.body}',
        );
      default:
        return _PopupStyle(
          backgroundColor: AppColors.iconGrey,
          icon: Icons.notifications_rounded,
          text: (n) => n.title,
        );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PopupStyle {
  const _PopupStyle({
    required this.backgroundColor,
    required this.icon,
    required this.text,
  });

  final Color backgroundColor;
  final IconData icon;
  final String Function(NotificationRow) text;
}
