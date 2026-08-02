import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat_message_row.dart';
import '../../../core/models/conversation_row.dart';
import '../../../core/models/host_listing_booking_thread.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/payment_row.dart';
import '../../../core/models/reservation_row.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/messaging_repository.dart';
import '../data/reservations_repository.dart';
import '../data/supabase_messaging_repository.dart';
import '../data/supabase_reservations_repository.dart';

final reservationsRepositoryProvider = Provider<ReservationsRepository>((ref) {
  return SupabaseReservationsRepository(ref.watch(supabaseClientProvider));
});

final reservationByIdProvider = FutureProvider.family<ReservationRow?, String>((
  ref,
  reservationId,
) {
  return ref.read(reservationsRepositoryProvider).getReservation(reservationId);
});

final reservationPaymentProvider = FutureProvider.family<PaymentRow?, String>((
  ref,
  reservationId,
) async {
  return ref
      .read(reservationsRepositoryProvider)
      .paymentForReservation(reservationId);
});

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return SupabaseMessagingRepository(ref.watch(supabaseClientProvider));
});

final driverActiveReservationsProvider = FutureProvider<List<ReservationRow>>((
  ref,
) async {
  final repo = ref.watch(reservationsRepositoryProvider);
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) return [];
  return repo.listDriverTrips(driverId: uid, activeOnly: true);
});

final driverPastReservationsProvider = FutureProvider<List<ReservationRow>>((
  ref,
) async {
  final repo = ref.watch(reservationsRepositoryProvider);
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) return [];
  return repo.listDriverTrips(driverId: uid, activeOnly: false);
});

final hostActiveReservationsProvider = FutureProvider<List<ReservationRow>>((
  ref,
) async {
  final repo = ref.watch(reservationsRepositoryProvider);
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) return [];
  return repo.listHostTrips(hostId: uid, activeOnly: true);
});

final hostPastReservationsProvider = FutureProvider<List<ReservationRow>>((
  ref,
) async {
  final repo = ref.watch(reservationsRepositoryProvider);
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) return [];
  return repo.listHostTrips(hostId: uid, activeOnly: false);
});

final messagingInboxProvider = FutureProvider<List<ConversationRow>>((
  ref,
) async {
  final repo = ref.watch(messagingRepositoryProvider);
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) return [];
  return repo.inboxForUser(uid);
});

final conversationMessagesProvider =
    StreamProvider.family<List<ChatMessageRow>, String>((ref, conversationId) {
      return ref
          .read(messagingRepositoryProvider)
          .watchMessages(conversationId);
    });

final hostListingActiveThreadsProvider =
    FutureProvider.family<List<HostListingBookingThread>, String>((
      ref,
      listingId,
    ) async {
      final uid = ref.watch(currentSessionProvider)?.user.id;
      if (uid == null) return [];
      return ref
          .read(messagingRepositoryProvider)
          .listHostListingThreads(
            hostId: uid,
            listingId: listingId,
            activeOnly: true,
          );
    });

final hostListingPastThreadsProvider =
    FutureProvider.family<List<HostListingBookingThread>, String>((
      ref,
      listingId,
    ) async {
      final uid = ref.watch(currentSessionProvider)?.user.id;
      if (uid == null) return [];
      return ref
          .read(messagingRepositoryProvider)
          .listHostListingThreads(
            hostId: uid,
            listingId: listingId,
            activeOnly: false,
          );
    });

// Driver: your active trips with listing rows for address search
typedef DriverTripRow = ({ReservationRow reservation, Listing? listing});

final driverActiveTripsProvider = FutureProvider<List<DriverTripRow>>((
  ref,
) async {
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) return [];
  final reservations = await ref
      .read(reservationsRepositoryProvider)
      .listDriverTrips(driverId: uid, activeOnly: true);
  final listings = ref.read(listingsRepositoryProvider);
  final out = <DriverTripRow>[];
  for (final r in reservations) {
    final l = await listings.getListingById(r.listingId);
    out.add((reservation: r, listing: l));
  }
  return out;
});

final driverPastTripsProvider = FutureProvider<List<DriverTripRow>>((
  ref,
) async {
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) return [];
  final reservations = await ref
      .read(reservationsRepositoryProvider)
      .listDriverTrips(driverId: uid, activeOnly: false);
  final listings = ref.read(listingsRepositoryProvider);
  final out = <DriverTripRow>[];
  for (final r in reservations) {
    final l = await listings.getListingById(r.listingId);
    out.add((reservation: r, listing: l));
  }
  return out;
});
