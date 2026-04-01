import '../../../core/map/map_filters.dart';
import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/booking_time_window.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_photo.dart';

// Host listings, availability, photos (Supabase impl in this folder)
abstract class ListingsRepository {
  Future<List<Listing>> getMyListings(String userId);

  Future<Listing?> getListingById(String id);

  Future<List<ListingPhoto>> getListingPhotos(String listingId);

  Future<void> setHeroPhotoSpotMarker({
    required String listingId,
    required double markerX,
    required double markerY,
  });

  Future<List<AvailabilityWeekly>> getAvailabilityWeekly(String listingId);

  Future<List<AvailabilitySpecific>> getAvailabilitySpecific(String listingId);

  Future<List<BookingTimeWindow>> getBookingBlocksOverlapping(
    String listingId, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  });

  Future<List<Listing>> getPublishedListingsForMap({
    MapFilters? filters,
    double? proximityUserLatitude,
    double? proximityUserLongitude,
  });

  Future<void> setAllAvailabilitySlotPrices({
    required String listingId,
    required double priceHour,
    double? priceDay,
  });

  Future<void> updateAvailabilityWeeklySlotPrices({
    required String slotId,
    required double priceHour,
    double? priceDay,
  });

  Future<AvailabilityWeekly> insertAvailabilityWeeklySlot({
    required String listingId,
    required int dayOfWeek,
    required String startTimeHhMm,
    required String endTimeHhMm,
    double priceHour = 0,
    double? priceDay,
  });

  Future<void> deleteAvailabilityWeeklySlot(String slotId);

  Future<Listing> createListing({
    required String hostId,
    required String address,
    required String city,
    String? postalCode,
    required String country,
    String? spotNumber,
    required double latitude,
    required double longitude,
    String availabilityMode = 'weekly',
  });

  Future<void> deleteListing(String listingId);

  Future<void> patchListing({
    required String listingId,
    String? address,
    String? city,
    String? postalCode,
    String? country,
    String? spotNumber,
    double? latitude,
    double? longitude,
    bool? isActive,
    bool? isPublished,
    bool? termsAccepted,
    DateTime? termsAcceptedAt,
    String? availabilityMode,
  });

  Future<ListingPhoto> addListingPhotoFromLocalPath({
    required String listingId,
    required String localFilePath,
    int sortOrder = 0,
  });

  Future<void> deleteListingPhoto(String photoId);

  Future<void> reorderListingPhotos({
    required String listingId,
    required List<String> photoIdsInOrder,
  });

  Future<AvailabilitySpecific> insertAvailabilitySpecificSlot({
    required String listingId,
    required DateTime start,
    required DateTime end,
    double priceHour = 0,
    double? priceDay,
  });

  Future<void> deleteAvailabilitySpecificSlot(String slotId);

  Future<void> updateAvailabilitySpecificSlotPrices({
    required String slotId,
    required double priceHour,
    double? priceDay,
  });
}
