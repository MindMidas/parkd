import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/notification_row.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/app_feedback.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/profile/providers/notifications_providers.dart';
import 'active_trip_chat_provider.dart';
import 'go_router_provider.dart';
import 'notification_preferences_provider.dart';
import 'shell_deep_link_provider.dart';

class RealtimeAlertsOverlay extends ConsumerStatefulWidget {
  const RealtimeAlertsOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RealtimeAlertsOverlay> createState() =>
      _RealtimeAlertsOverlayState();
}

class _RealtimeAlertsOverlayState extends ConsumerState<RealtimeAlertsOverlay> {
  final Set<String> _seen = {};
  bool _hydrated = false;
  NotificationRow? _visible;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    ref.listenManual(currentSessionProvider, (previous, next) {
      if (previous?.user.id == next?.user.id) return;
      _seen.clear();
      _hydrated = false;
      _hide();
    });
    ref.listenManual(myNotificationFeedProvider, (previous, next) {
      final rows = next.value?.latest;
      if (rows == null) return;
      if (!_hydrated) {
        _seen.addAll(rows.map((row) => row.id));
        _hydrated = true;
        return;
      }
      final newcomers =
          rows.where((row) => !_seen.contains(row.id)).toList(growable: false)
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final row in newcomers) {
        _seen.add(row.id);
        if (ref.read(notificationBannersMutedProvider)) continue;
        if (_isOpenConversation(row)) continue;
        _show(row);
      }
    });
  }

  bool _isOpenConversation(NotificationRow row) {
    if (row.type != ParkdNotificationType.messageReceived) return false;
    final activeReservation = ref.read(activeTripChatProvider);
    return activeReservation != null && activeReservation == row.reservationId;
  }

  void _show(NotificationRow row) {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() => _visible = row);
    _dismissTimer = Timer(const Duration(seconds: 8), _hide);
  }

  void _hide() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (mounted && _visible != null) setState(() => _visible = null);
  }

  Future<void> _open(NotificationRow row) async {
    // Banner lives in MaterialApp.router's builder (above the Navigator), so
    // Shell deep links instead of context.push from the MaterialApp builder.
    final router = ref.read(goRouterProvider);
    final reservationId = row.reservationId;
    _hide();
    if (row.type == ParkdNotificationType.messageReceived &&
        reservationId != null &&
        reservationId.isNotEmpty) {
      // Stay inside /home so bottom nav remains; nested stack handles Back.
      if (router.state.matchedLocation != '/home') {
        router.go('/home');
      }
      ref
          .read(shellDeepLinkProvider.notifier)
          .openReservationMessages(reservationId);
    } else {
      final tab = row.hub == NotificationHub.reservations
          ? 'reservations'
          : 'hosting';
      router.go('/home?tab=$tab');
    }
    try {
      await ref.read(notificationsRemoteProvider).markRead(row.id);
    } catch (_) {}
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final row = _visible;
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        widget.child,
        if (row != null)
          Positioned(
            top: topInset + AppSpacing.sm,
            left: AppSpacing.md,
            right: AppSpacing.md,
            child: Semantics(
              liveRegion: true,
              label: '${row.title}. ${row.body}',
              child: Dismissible(
                key: ValueKey('notification_banner_${row.id}'),
                direction: DismissDirection.horizontal,
                onDismissed: (_) => _hide(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.shadowElevated,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: AppColors.primaryBlue,
                    elevation: 0,
                    shadowColor: AppColors.transparent,
                    surfaceTintColor: AppColors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        AppFeedback.selection(context);
                        _open(row);
                      },
                      splashColor: AppColors.onPrimary.withValues(alpha: 0.22),
                      highlightColor:
                          AppColors.onPrimary.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              row.type ==
                                      ParkdNotificationType.messageReceived
                                  ? Icons.chat_bubble_rounded
                                  : Icons.notifications_rounded,
                              color: AppColors.onPrimary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    row.title,
                                    style: AppTypography.bodyStrong.copyWith(
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    row.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.onPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.onPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
