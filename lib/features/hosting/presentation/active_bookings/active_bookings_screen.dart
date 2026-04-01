import 'package:flutter/material.dart';

import '../../../profile/providers/notifications_providers.dart';
import '../../../reservations/providers/reservations_providers.dart';
import '../host_bookings_by_listing_screen.dart';
import 'booking_messages_screen.dart';

class ActiveBookingsScreen extends StatelessWidget {
  const ActiveBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HostBookingsByListingScreen(
      title: 'Active Bookings',
      reservationsProvider: hostActiveReservationsProvider,
      whenEmptyList: 'No active bookings',
      buildMessagesRoute: (listing) => BookingMessagesScreen(listing: listing),
      listingUnreadMapProvider: hostListingActiveBookingsUnreadMapProvider,
    );
  }
}
