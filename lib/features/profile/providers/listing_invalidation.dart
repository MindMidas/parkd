import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/providers/map_providers.dart';
import '../../reservations/providers/reservations_providers.dart';
import 'profile_providers.dart';

/// Call after any server-side change to a listing so host lists, map pins, trip
/// rows, and booking threads pick up new photos, prices, or address text
void invalidateListingSurfaces(WidgetRef ref, String listingId) {
  ref.invalidate(myListingsForCurrentUserProvider);
  ref.invalidate(listingByIdProvider(listingId));
  ref.invalidate(listingPhotosProvider(listingId));
  ref.invalidate(listingAvailabilityWeeklyProvider(listingId));
  ref.invalidate(listingAvailabilitySpecificProvider(listingId));
  ref.invalidate(mapPublishedListingsProvider);
  ref.invalidate(driverActiveTripsProvider);
  ref.invalidate(driverPastTripsProvider);
  ref.invalidate(hostListingActiveThreadsProvider(listingId));
  ref.invalidate(hostListingPastThreadsProvider(listingId));
}
