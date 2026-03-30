import 'package:flutter/material.dart';

import '../../../reservations/providers/reservations_providers.dart';
import '../host_bookings_by_listing_screen.dart';
import 'past_booking_messages_screen.dart';

class PastBookingsScreen extends StatelessWidget {
  const PastBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return HostBookingsByListingScreen(
      title: 'Past Bookings',
      reservationsProvider: hostPastReservationsProvider,
      whenEmptyList: 'No past bookings',
      buildMessagesRoute: (listing) =>
          PastBookingMessagesScreen(listing: listing),
    );
  }
}
