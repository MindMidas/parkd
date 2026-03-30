import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/map/providers/map_providers.dart';
import '../features/profile/providers/profile_providers.dart';
import '../features/reservations/providers/reservations_providers.dart';

// Call after listing changes on server so lists, map, & trips refresh
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
