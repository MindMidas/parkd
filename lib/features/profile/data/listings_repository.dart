import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_photo.dart';

/// Abstracts fetching and mutating listings for the current host.
/// Implement with [DummyListingsRepository] for UI-only; replace with
/// Supabase implementation when wiring (see database/README.md).
abstract class ListingsRepository {
  /// Listings owned by [userId] (host). Used by Manage Listings screen.
  Future<List<Listing>> getMyListings(String userId);

  /// Single listing by id. Used by Edit Listing screen.
  Future<Listing?> getListingById(String id);

  /// Photos for a listing, ordered by sort_order. Used for hero and gallery.
  Future<List<ListingPhoto>> getListingPhotos(String listingId);

  /// Weekly availability (day_of_week + start/end time). Use when listing uses weekly slots.
  Future<List<AvailabilityWeekly>> getAvailabilityWeekly(String listingId);

  /// Specific date-range availability. Use when listing uses date-range slots.
  Future<List<AvailabilitySpecific>> getAvailabilitySpecific(String listingId);
}
