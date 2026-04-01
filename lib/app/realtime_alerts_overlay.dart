import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/notification_row.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/widgets.dart';
import 'active_trip_chat_foreground_provider.dart';
import 'go_router_provider.dart';
import 'notification_popup_muted_provider.dart';
import '../core/notifications/notification_hub_counts.dart';
import 'message_notification_navigation.dart';
import '../core/utils/profile_avatar_image_provider.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/profile/providers/notifications_providers.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/reservations/providers/reservations_providers.dart';

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
  NotificationRow? _topBanner;
  Timer? _bannerTimer;

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _dismissBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    if (_topBanner != null && mounted) {
      setState(() => _topBanner = null);
    }
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(currentSessionProvider, (previous, next) {
      final prevId = previous?.user.id;
      final nextId = next?.user.id;
      if (prevId != nextId) {
        _seenNotificationIds.clear();
        _hydrated = false;
        _dismissBanner();
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
        final mutePopups = ref.read(notificationPopupsMutedProvider);
        for (final n in newcomers) {
          _seenNotificationIds.add(n.id);
          if (!mutePopups && !_suppressMessageBannerForForegroundChat(n)) {
            _showTopBanner(n);
          }
        }
      },
    );
  }

  bool _suppressMessageBannerForForegroundChat(NotificationRow n) {
    if (n.type != 'message_received') return false;
    final active = ref.read(activeTripChatForegroundProvider);
    if (active == null) return false;

    final notifConv = _valueAsString(n.dataJson['conversation_id']);
    if (notifConv != null &&
        active.conversationId != null &&
        active.conversationId == notifConv) {
      return true;
    }

    final notifRes = notificationReservationId(n) ??
        _valueAsString(n.sourceEntityId);
    if (notifRes != null &&
        notifRes.isNotEmpty &&
        notifRes == active.reservationId) {
      return true;
    }
    return false;
  }

  void _showTopBanner(NotificationRow notification) {
    if (!mounted) return;
    _bannerTimer?.cancel();
    setState(() => _topBanner = notification);
    _bannerTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() => _topBanner = null);
      }
    });
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

    try {
      _dismissBanner();

      final uid = ref.read(currentSessionProvider)?.user.id;
      if (uid != null) {
        await ref.read(notificationsRemoteProvider).markRead(notification.id);
      }

      if (!mounted) return;

      if (notification.type == 'message_received') {
        final deepLinked =
            await tryNavigateMessageNotificationDeepLink(ref, notification);
        if (deepLinked && mounted) return;
      }

      if (notification.type == 'reservation_confirmed') {
        final deepLinked =
            await tryNavigateReservationConfirmedDeepLink(ref, notification);
        if (deepLinked && mounted) return;
        return;
      }

      if (!mounted) return;

      var peerDisplayName = 'Messages';
      if (notification.type == 'message_received') {
        final sid = _valueAsString(notification.dataJson['sender_id']);
        if (sid != null) {
          final p = await ref.read(profileRepositoryProvider).getProfile(sid);
          final n = p?.displayName.trim() ?? '';
          if (n.isNotEmpty) peerDisplayName = n;
        }
      }

      if (!mounted) return;

      await ref.read(goRouterProvider).push<void>(
            '/trip-conversation',
            extra: <String, dynamic>{
              'reservationId': reservationId,
              'conversationId': conversationId,
              'peerDisplayName': peerDisplayName,
            },
          );
    } catch (e, stack) {
      debugPrint('Navigation error: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Widget _buildGenericBannerBody(NotificationRow n, _PopupStyle style) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(style.icon, color: AppColors.onPrimary, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (style.eyebrow != null && style.eyebrow!.trim().isNotEmpty) ...[
                Text(
                  style.eyebrow!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                style.text(n),
                maxLines: n.type == 'reservation_confirmed' ? 1 : 3,
                overflow: TextOverflow.ellipsis,
                softWrap: n.type != 'reservation_confirmed',
                style: AppTypography.bodySecondary.copyWith(
                  color: AppColors.onPrimary,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 2),
        _BannerChevronButton(onPressed: () => _openMessages(n)),
      ],
    );
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
          eyebrow: 'NEW BOOKING',
          text: (n) => n.body,
        );
      case 'message_received':
        return _PopupStyle(
          backgroundColor: AppColors.primaryBlue,
          icon: Icons.chat_bubble_rounded,
          eyebrow: null,
          text: (n) => 'New message: ${n.body}',
        );
      default:
        return _PopupStyle(
          backgroundColor: AppColors.iconGrey,
          icon: Icons.notifications_rounded,
          eyebrow: 'UPDATE',
          text: (n) => n.title,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _topBanner;
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (banner != null)
          Positioned(
            left: 16,
            right: 16,
            top: topPad + 8,
            child: Dismissible(
              key: ValueKey<String>('banner_${banner.id}'),
              direction: DismissDirection.horizontal,
              onDismissed: (_) => _dismissBanner(),
              child: Material(
                elevation: 6,
                shadowColor: AppColors.shadowFloating,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                color: _styleFor(banner.type).backgroundColor,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openMessages(banner),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    child: banner.type == 'message_received'
                        ? _TopMessageBannerContent(
                            notification: banner,
                            onOpen: () => _openMessages(banner),
                          )
                        : _buildGenericBannerBody(banner, _styleFor(banner.type)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Top snack banner copy for new messages (driver vs host wording).
class _TopMessageBannerContent extends ConsumerWidget {
  const _TopMessageBannerContent({
    required this.notification,
    required this.onOpen,
  });

  final NotificationRow notification;
  final VoidCallback onOpen;

  static String? _str(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }

  static String? _messageContextKeyword(Object? raw) {
    if (raw is! String) return null;
    final s = raw.trim().toLowerCase();
    return s.isEmpty ? null : s;
  }

  static String _contextEyebrow(NotificationRow n) {
    final kw = _messageContextKeyword(n.dataJson['message_context']);
    if (kw == 'booking') {
      return 'BOOKING MESSAGE';
    }
    if (kw == 'reservation') {
      return 'RESERVATION MESSAGE';
    }
    return 'NEW MESSAGE';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = notification.body.trim();
    final senderId = _str(notification.dataJson['sender_id']);
    final prof = senderId != null
        ? ref.watch(profileByUserIdProvider(senderId)).asData?.value
        : null;
    final senderName = prof?.displayName.trim().isNotEmpty == true
        ? prof!.displayName.trim()
        : 'Someone';
    final resId = _str(notification.dataJson['reservation_id']);
    final cid = _str(notification.dataJson['conversation_id']);
    final reservation = resId != null
        ? ref.watch(reservationByIdProvider(resId)).asData?.value
        : null;
    final conversation = cid != null
        ? ref.watch(conversationByIdProvider(cid)).asData?.value
        : null;
    final roleBracket = notification.resolvedMessageSenderRoleBracket(
      reservationHostId: reservation?.hostId ?? conversation?.hostId,
      reservationDriverId: reservation?.driverId ?? conversation?.driverId,
    );
    final headline = roleBracket != null
        ? '${_contextEyebrow(notification)} $roleBracket'
        : _contextEyebrow(notification);
    final senderLine = senderName;
    final avatarProvider = profileAvatarImageProvider(prof);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _MessageSnackAvatar(imageProvider: avatarProvider),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                headline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.onPrimary.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.35,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                senderLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: AppTypography.bodyStrong.copyWith(
                  color: AppColors.onPrimary,
                  fontSize: 15,
                ),
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTypography.bodySecondary.copyWith(
                    color: AppColors.onPrimary.withValues(alpha: 0.92),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        _BannerChevronButton(onPressed: onOpen),
      ],
    );
  }
}

class _BannerChevronButton extends StatelessWidget {
  const _BannerChevronButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      style: IconButton.styleFrom(
        foregroundColor: AppColors.onPrimary,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.chevron_right_rounded, size: 26),
    );
  }
}

class _MessageSnackAvatar extends StatelessWidget {
  const _MessageSnackAvatar({this.imageProvider});

  final ImageProvider? imageProvider;

  @override
  Widget build(BuildContext context) {
    if (imageProvider == null) {
      return AppMenuProfileAvatar(
        imageProvider: null,
        size: 44,
      );
    }
    return ClipOval(
      child: Image(
        image: imageProvider!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const AppMenuProfileAvatar(
          imageProvider: null,
          size: 44,
        ),
      ),
    );
  }
}

class _PopupStyle {
  const _PopupStyle({
    required this.backgroundColor,
    required this.icon,
    this.eyebrow,
    required this.text,
  });

  final Color backgroundColor;
  final IconData icon;
  final String? eyebrow;
  final String Function(NotificationRow) text;
}
