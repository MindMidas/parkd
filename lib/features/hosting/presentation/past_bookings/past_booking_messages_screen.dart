import 'package:flutter/material.dart';

import '../../../../core/models/listing.dart';
import '../host_listing_booking_threads_scaffold.dart';

// Host past-trip threads for one listing
class PastBookingMessagesScreen extends StatelessWidget {
  const PastBookingMessagesScreen({
    super.key,
    required this.listing,
  });

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return HostListingBookingThreadsScaffold(
      listing: listing,
      scope: HostListingThreadsScope.past,
      emptyWhenNoThreads: 'No past bookings for this spot.',
    );
  }
}
