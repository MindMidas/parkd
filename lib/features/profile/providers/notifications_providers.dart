import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/notification_row.dart';
import '../../../core/models/reservation_row.dart';
import '../../../core/notifications/message_notification_trip_hub.dart';
import '../../../core/notifications/notification_hub_counts.dart';
import '../../../core/notifications/reservation_active_window.dart';
import '../../../core/supabase/notifications_remote.dart';
import '../../auth/providers/auth_providers.dart';
import '../../reservations/providers/reservations_providers.dart';

final notificationsRemoteProvider = Provider<NotificationsRemote>((ref) {
  return NotificationsRemote(ref.watch(supabaseClientProvider));
});

final myNotificationsProvider = StreamProvider<List<NotificationRow>>((ref) {
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) {
    return Stream.value(const <NotificationRow>[]);
  }
  return ref.read(notificationsRemoteProvider).watchForUser(uid);
});

final myUnreadNotificationsCountProvider = Provider<int>((ref) {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  return rows.where((n) => !n.isRead).length;
});

// Resolved hub counts for bottom nav (uses reservation + sender when message_context is missing).
final notificationNavHubCountsProvider =
    FutureProvider<({int hosting, int reservations, int account})>((ref) async {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  final repo = ref.read(reservationsRepositoryProvider);
  Future<ReservationRow?> getRes(String id) => repo.getReservation(id);

  var hosting = 0;
  var reservations = 0;
  var account = 0;

  for (final n in rows) {
    if (n.isRead) continue;
    switch (n.type) {
      case 'reservation_confirmed':
      case 'review_received':
        hosting++;
        break;
      case 'message_received':
        final hub = await resolveMessageTripHub(n, getRes);
        if (hub == MessageTripHub.hostingTab) {
          hosting++;
        } else if (hub == MessageTripHub.reservationsTab) {
          reservations++;
        } else {
          account++;
        }
        break;
      default:
        account++;
    }
  }
  return (hosting: hosting, reservations: reservations, account: account);
});

int _syncHostingHubFallback(List<NotificationRow> rows) {
  return rows.where(isUnreadHostingHubNotification).length;
}

int _syncReservationsHubFallback(List<NotificationRow> rows) {
  return rows.where(isUnreadReservationsHubNotification).length;
}

int _syncAccountHubFallback(List<NotificationRow> rows) {
  return rows
      .where(
        (n) =>
            !n.isRead &&
            !isUnreadHostingHubNotification(n) &&
            !isUnreadReservationsHubNotification(n),
      )
      .length;
}

// Bottom nav Hosting tab: host bookings, reviews, and driver or host chat unread.
final hostingHubUnreadCountProvider = Provider<int>((ref) {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  final async = ref.watch(notificationNavHubCountsProvider);
  return async.when(
    data: (d) => d.hosting,
    loading: () => _syncHostingHubFallback(rows),
    error: (err, _) => _syncHostingHubFallback(rows),
  );
});

// Bottom nav Reservations tab: trip chat unread (host or driver side).
final reservationsHubUnreadCountProvider = Provider<int>((ref) {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  final async = ref.watch(notificationNavHubCountsProvider);
  return async.when(
    data: (d) => d.reservations,
    loading: () => _syncReservationsHubFallback(rows),
    error: (err, _) => _syncReservationsHubFallback(rows),
  );
});

// Bottom nav: Account - only unread not attributed to Hosting or Reservations.
final accountHubUnreadCountProvider = Provider<int>((ref) {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  final async = ref.watch(notificationNavHubCountsProvider);
  return async.when(
    data: (d) => d.account,
    loading: () => _syncAccountHubFallback(rows),
    error: (err, _) => _syncAccountHubFallback(rows),
  );
});

final hostingReservationConfirmedUnreadCountProvider = Provider<int>((ref) {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  return rows.where((n) => !n.isRead && n.type == 'reservation_confirmed').length;
});

final hostingManageListingsUnreadCountProvider = Provider<int>((ref) {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  return rows.where(isUnreadHostingManageListingsNotification).length;
});

Future<({int active, int past})> _bucketMessagesByActiveTripForTab(
  Ref ref,
  List<NotificationRow> rows,
  MessageTripHub targetTab,
) async {
  final repo = ref.read(reservationsRepositoryProvider);
  Future<ReservationRow?> getRes(String id) => repo.getReservation(id);

  final candidates = <NotificationRow>[];
  for (final n in rows) {
    if (n.isRead || n.type != 'message_received') continue;
    final hub = await resolveMessageTripHub(n, getRes);
    if (hub == targetTab) candidates.add(n);
  }

  final ids = <String>{};
  for (final n in candidates) {
    final id = notificationReservationId(n);
    if (id != null) ids.add(id);
  }
  if (ids.isEmpty) {
    return (active: 0, past: 0);
  }
  final byId = <String, ReservationRow>{};
  for (final id in ids) {
    final r = await repo.getReservation(id);
    if (r != null) byId[id] = r;
  }
  final now = DateTime.now().toUtc();
  var active = 0;
  var past = 0;
  for (final n in candidates) {
    final id = notificationReservationId(n);
    if (id == null) continue;
    final r = byId[id];
    if (r == null) {
      past++;
      continue;
    }
    if (reservationAppearsInActiveTripsList(r, now)) {
      active++;
    } else {
      past++;
    }
  }
  return (active: active, past: past);
}

// Driver-side (HOST sent) message notifications split by active vs past trip.
final driverSideMessageUnreadBucketsProvider =
    FutureProvider<({int active, int past})>((ref) async {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  return _bucketMessagesByActiveTripForTab(ref, rows, MessageTripHub.reservationsTab);
});

// Host-side (DRIVER sent) message notifications split by active vs past trip.
final hostSideMessageUnreadBucketsProvider =
    FutureProvider<({int active, int past})>((ref) async {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  return _bucketMessagesByActiveTripForTab(ref, rows, MessageTripHub.hostingTab);
});

// Hosting hub Active Bookings: new trip requests plus driver messages on active trips.
final hostingActiveBookingsMenuUnreadProvider = Provider<int>((ref) {
  final confirmed = ref.watch(hostingReservationConfirmedUnreadCountProvider);
  final buckets = ref.watch(hostSideMessageUnreadBucketsProvider);
  final msgActive = buckets.asData?.value.active ?? 0;
  return confirmed + msgActive;
});

// Hosting hub Past Bookings: driver messages for ended or unknown trips only.
final hostingPastBookingsMenuUnreadProvider = Provider<int>((ref) {
  final buckets = ref.watch(hostSideMessageUnreadBucketsProvider);
  return buckets.asData?.value.past ?? 0;
});

// Reservations hub active trips row.
final reservationsActiveMenuUnreadProvider = Provider<int>((ref) {
  final buckets = ref.watch(driverSideMessageUnreadBucketsProvider);
  return buckets.asData?.value.active ?? 0;
});

// Reservations hub past trips row.
final reservationsPastMenuUnreadProvider = Provider<int>((ref) {
  final buckets = ref.watch(driverSideMessageUnreadBucketsProvider);
  return buckets.asData?.value.past ?? 0;
});

// Unread message_received rows for this reservation (current user is recipient).
final unreadMessageNotificationsForReservationProvider =
    Provider.family<int, String>((ref, reservationId) {
  final id = reservationId.trim();
  if (id.isEmpty) return 0;
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  return rows
      .where(
        (n) =>
            !n.isRead &&
            n.type == 'message_received' &&
            notificationReservationId(n) == id,
      )
      .length;
});

Future<Map<String, int>> _hostListingUnreadMap(Ref ref) async {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  final repo = ref.read(reservationsRepositoryProvider);
  Future<ReservationRow?> getRes(String id) => repo.getReservation(id);

  final candidates = <NotificationRow>[];
  for (final n in rows) {
    if (n.isRead || n.type != 'message_received') continue;
    final hub = await resolveMessageTripHub(n, getRes);
    if (hub == MessageTripHub.hostingTab) candidates.add(n);
  }
  if (candidates.isEmpty) return {};

  final ids = <String>{};
  for (final n in candidates) {
    final rid = notificationReservationId(n);
    if (rid != null) ids.add(rid);
  }
  final resById = <String, ReservationRow>{};
  for (final id in ids) {
    final r = await repo.getReservation(id);
    if (r != null) resById[id] = r;
  }
  final out = <String, int>{};
  for (final n in candidates) {
    final rid = notificationReservationId(n);
    if (rid == null) continue;
    final r = resById[rid];
    if (r == null) continue;
    out.update(r.listingId, (v) => v + 1, ifAbsent: () => 1);
  }
  return out;
}

Map<String, int> _mergeListingUnreadMaps(
  Map<String, int> a,
  Map<String, int> b,
) {
  final out = Map<String, int>.from(a);
  for (final e in b.entries) {
    out.update(e.key, (v) => v + e.value, ifAbsent: () => e.value);
  }
  return out;
}

Map<String, int> _listingUnreadReservationConfirmedByListingId(
  List<NotificationRow> rows,
) {
  final out = <String, int>{};
  for (final n in rows) {
    if (n.isRead || n.type != 'reservation_confirmed') continue;
    final raw = n.dataJson['listing_id'];
    if (raw is! String || raw.trim().isEmpty) continue;
    final id = raw.trim();
    out.update(id, (v) => v + 1, ifAbsent: () => 1);
  }
  return out;
}

// Host hub: unread driver to host messages rolled up per listing row.
final hostListingUnreadMessageMapProvider =
    FutureProvider<Map<String, int>>((ref) async {
  return _hostListingUnreadMap(ref);
});

// Active Bookings listing rows: unread driver messages + unread new-booking alerts per listing.
final hostListingActiveBookingsUnreadMapProvider =
    FutureProvider<Map<String, int>>((ref) async {
  ref.watch(myNotificationsProvider);
  final messageMap = await _hostListingUnreadMap(ref);
  final rows = ref.read(myNotificationsProvider).value ?? const <NotificationRow>[];
  final confirmed = _listingUnreadReservationConfirmedByListingId(rows);
  return _mergeListingUnreadMaps(messageMap, confirmed);
});
