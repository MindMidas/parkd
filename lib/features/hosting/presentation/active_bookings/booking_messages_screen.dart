import 'package:flutter/material.dart';

import '../../../../core/models/listing.dart';
import '../host_listing_booking_threads_scaffold.dart';

// host inbox for one listing
class BookingMessagesScreen extends StatelessWidget {
  const BookingMessagesScreen({
    super.key,
    required this.listing,
  });

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return HostListingBookingThreadsScaffold(
      listing: listing,
      scope: HostListingThreadsScope.active,
      emptyWhenNoThreads: 'No active bookings for this spot.',
    );
  }
}
