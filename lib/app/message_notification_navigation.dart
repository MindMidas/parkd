import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/notification_row.dart';
import '../core/models/reservation_row.dart';
import '../core/models/reservation_status.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/reservations/providers/reservations_providers.dart';
import 'go_router_provider.dart';
import 'main_tab.dart';
import 'message_notification_deep_link.dart';

String? notificationDataString(Object? raw) {
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  return null;
}

bool reservationIsActiveLikeForMessageDeepLink(ReservationRow r) {
  return r.status != ReservationStatus.completed &&
      r.status != ReservationStatus.cancelled;
}

/// Schedules nested-tab navigation to the message thread (host or driver stack).
/// Returns true when the deep link was applied; otherwise the caller may fall back
/// (e.g. root [TripConversationScreen] route).
Future<bool> tryNavigateMessageNotificationDeepLink(
  WidgetRef ref,
  NotificationRow notification,
) async {
  if (notification.type != 'message_received') return false;

  final conversationId =
      notificationDataString(notification.dataJson['conversation_id']);
  final reservationId =
      notificationDataString(notification.dataJson['reservation_id']) ??
      notification.sourceEntityId;

  if (reservationId == null || reservationId.isEmpty) return false;

  final senderId = notificationDataString(notification.dataJson['sender_id']);
  var peerDisplayName = 'Messages';
  if (senderId != null) {
    final p = await ref.read(profileRepositoryProvider).getProfile(senderId);
    final n = p?.displayName.trim() ?? '';
    if (n.isNotEmpty) peerDisplayName = n;
  }

  final uid = ref.read(currentSessionProvider)?.user.id;
  if (uid == null) return false;

  final row =
      await ref.read(reservationsRepositoryProvider).getReservation(reservationId);
  if (row == null) return false;

  final MessageDeepLinkRole role;
  if (uid == row.hostId) {
    role = MessageDeepLinkRole.host;
  } else if (uid == row.driverId) {
    role = MessageDeepLinkRole.driver;
  } else {
    return false;
  }

  final listing =
      await ref.read(listingsRepositoryProvider).getListingById(row.listingId);
  if (listing == null) return false;

  final activeFlow = reservationIsActiveLikeForMessageDeepLink(row);

  final intent = MessageDeepLinkIntent(
    role: role,
    reservation: row,
    listing: listing,
    conversationId: conversationId,
    peerDisplayName: peerDisplayName,
    activeFlow: activeFlow,
  );

  final tab =
      role == MessageDeepLinkRole.host ? MainTab.hosting : MainTab.reservations;
  ref.read(goRouterProvider).go('/home?tab=${MainTab.toQuery(tab)}');

  // Emit after navigation so [HomeMapScreen] is in the tree and can listen.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(messageDeepLinkProvider.notifier).emit(intent);
  });

  return true;
}

/// Host-only: Hosting → Active bookings → listing threads → chat → booking details
/// (same stack as a message deep link, with details opened on top).
Future<bool> tryNavigateReservationConfirmedDeepLink(
  WidgetRef ref,
  NotificationRow notification,
) async {
  if (notification.type != 'reservation_confirmed') return false;

  final reservationId =
      notificationDataString(notification.dataJson['reservation_id']) ??
      notification.sourceEntityId;
  if (reservationId == null || reservationId.isEmpty) return false;

  final uid = ref.read(currentSessionProvider)?.user.id;
  if (uid == null) return false;

  final row =
      await ref.read(reservationsRepositoryProvider).getReservation(reservationId);
  if (row == null) return false;
  if (uid != row.hostId) return false;

  final listing =
      await ref.read(listingsRepositoryProvider).getListingById(row.listingId);
  if (listing == null) return false;

  var peerDisplayName = 'Guest';
  final p = await ref.read(profileRepositoryProvider).getProfile(row.driverId);
  final n = p?.displayName.trim() ?? '';
  if (n.isNotEmpty) peerDisplayName = n;

  final activeFlow = reservationIsActiveLikeForMessageDeepLink(row);

  final intent = MessageDeepLinkIntent(
    role: MessageDeepLinkRole.host,
    reservation: row,
    listing: listing,
    conversationId: null,
    peerDisplayName: peerDisplayName,
    activeFlow: activeFlow,
    openBookingDetailsOnTop: true,
  );

  ref.read(goRouterProvider).go('/home?tab=${MainTab.toQuery(MainTab.hosting)}');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(messageDeepLinkProvider.notifier).emit(intent);
  });

  return true;
}
