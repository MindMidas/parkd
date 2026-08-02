import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/listing.dart';
import '../core/models/reservation_row.dart';
import '../core/models/reservation_status.dart';
import '../core/widgets/widgets.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/hosting/presentation/active_bookings/active_bookings_screen.dart';
import '../features/hosting/presentation/active_bookings/booking_details_screen.dart';
import '../features/hosting/presentation/active_bookings/booking_messages_screen.dart';
import '../features/hosting/presentation/past_bookings/past_booking_messages_screen.dart';
import '../features/hosting/presentation/past_bookings/past_bookings_screen.dart';
import '../features/map/presentation/main_tab.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/reservations/presentation/active_reservations/active_reservations_screen.dart';
import '../features/reservations/presentation/active_reservations/reservation_details_screen.dart';
import '../features/reservations/presentation/past_reservations/past_reservations_screen.dart';
import '../features/reservations/presentation/trip_conversation_screen.dart';
import '../features/reservations/providers/reservations_providers.dart';

/// Opens a reservation chat inside Hosting or Reservations so the bottom nav
/// stays and Back walks the normal menu stack.
Future<int?> prepareReservationMessageStack({
  required WidgetRef ref,
  required String reservationId,
}) async {
  final uid = ref.read(currentSessionProvider)?.user.id;
  if (uid == null) return null;

  final reservation = await ref.read(
    reservationByIdProvider(reservationId).future,
  );
  if (reservation == null) return null;

  final isHost = reservation.hostId == uid;
  final isDriver = reservation.driverId == uid;
  if (!isHost && !isDriver) return null;

  return isHost ? MainTab.hosting : MainTab.reservations;
}

Future<void> pushReservationMessageStack({
  required WidgetRef ref,
  required NavigatorState nav,
  required String reservationId,
}) async {
  final uid = ref.read(currentSessionProvider)?.user.id;
  if (uid == null) return;

  final reservation = await ref.read(
    reservationByIdProvider(reservationId).future,
  );
  if (reservation == null || !nav.mounted) return;

  final isHost = reservation.hostId == uid;
  final isDriver = reservation.driverId == uid;
  if (!isHost && !isDriver) return;

  final isPast =
      reservation.status == ReservationStatus.completed ||
      reservation.status == ReservationStatus.cancelled;

  final listing = await ref.read(
    listingByIdProvider(reservation.listingId).future,
  );
  if (!nav.mounted) return;

  final peerId = isHost ? reservation.driverId : reservation.hostId;
  final peer = await ref.read(profileByUserIdProvider(peerId).future);
  if (!nav.mounted) return;
  final peerName = peer?.displayName ?? (isHost ? 'Driver' : 'Host');

  nav.popUntil((route) => route.isFirst);

  if (isHost) {
    await _pushHostStack(
      nav: nav,
      reservation: reservation,
      listing: listing,
      peerName: peerName,
      isPast: isPast,
    );
  } else {
    await _pushDriverStack(
      nav: nav,
      reservation: reservation,
      listing: listing,
      peerName: peerName,
      isPast: isPast,
    );
  }
}

Future<void> _pushHostStack({
  required NavigatorState nav,
  required ReservationRow reservation,
  required Listing? listing,
  required String peerName,
  required bool isPast,
}) async {
  await nav.push<void>(
    AppPageRoute<void>(
      builder: (_) =>
          isPast ? const PastBookingsScreen() : const ActiveBookingsScreen(),
    ),
  );
  if (!nav.mounted) return;

  if (listing != null) {
    await nav.push<void>(
      AppPageRoute<void>(
        builder: (_) => isPast
            ? PastBookingMessagesScreen(listing: listing)
            : BookingMessagesScreen(listing: listing),
      ),
    );
    if (!nav.mounted) return;
  }

  await nav.push<void>(
    AppPageRoute<void>(
      builder: (context) => TripConversationScreen(
        reservationId: reservation.id,
        peerUserId: reservation.driverId,
        peerDisplayName: peerName,
        viewTripLabel: listing == null ? null : 'View booking',
        onViewTrip: listing == null
            ? null
            : () {
                Navigator.of(context).push<void>(
                  AppPageRoute<void>(
                    builder: (_) => BookingDetailsScreen(
                      reservation: reservation,
                      listing: listing,
                    ),
                  ),
                );
              },
      ),
    ),
  );
}

Future<void> _pushDriverStack({
  required NavigatorState nav,
  required ReservationRow reservation,
  required Listing? listing,
  required String peerName,
  required bool isPast,
}) async {
  await nav.push<void>(
    AppPageRoute<void>(
      builder: (_) => isPast
          ? const PastReservationsScreen()
          : const ActiveReservationsScreen(),
    ),
  );
  if (!nav.mounted) return;

  await nav.push<void>(
    AppPageRoute<void>(
      builder: (_) =>
          ReservationDetailsScreen(reservation: reservation, listing: listing),
    ),
  );
  if (!nav.mounted) return;

  await nav.push<void>(
    AppPageRoute<void>(
      builder: (_) => TripConversationScreen(
        reservationId: reservation.id,
        peerUserId: reservation.hostId,
        peerDisplayName: peerName,
      ),
    ),
  );
}
