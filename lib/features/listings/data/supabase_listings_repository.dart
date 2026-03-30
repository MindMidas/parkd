import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cloudinary/cloudinary_uploader.dart';
import '../../../core/map/map_filters.dart';
import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/booking_time_window.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_photo.dart';
import '../../../core/supabase/listing_availability_remote.dart';
import '../../../core/supabase/listing_photos_remote.dart';
import '../../../core/supabase/listings_remote.dart';
import '../../../core/supabase/reservations_remote.dart';
import 'listings_repository.dart';

class SupabaseListingsRepository implements ListingsRepository {
  SupabaseListingsRepository(
    SupabaseClient client, {
    CloudinaryUploader? cloudinary,
  })  : _listings = ListingsRemote(client),
        _photos = ListingPhotosRemote(client, cloudinary: cloudinary),
        _availability = ListingAvailabilityRemote(client),
        _reservations = ReservationsRemote(client);

  final ListingsRemote _listings;
  final ListingPhotosRemote _photos;
  final ListingAvailabilityRemote _availability;
  final ReservationsRemote _reservations;

  @override
  Future<List<Listing>> getMyListings(String userId) =>
      _listings.listByHostId(userId);

  @override
  Future<Listing?> getListingById(String id) => _listings.fetchById(id);

  @override
  Future<List<ListingPhoto>> getListingPhotos(String listingId) =>
      _photos.listForListing(listingId);

  @override
  Future<void> setHeroPhotoSpotMarker({
    required String listingId,
    required double markerX,
    required double markerY,
  }) =>
      _photos.setHeroMarker(
        listingId: listingId,
        markerX: markerX,
        markerY: markerY,
      );

  @override
  Future<List<AvailabilityWeekly>> getAvailabilityWeekly(String listingId) =>
      _availability.listWeekly(listingId);

  @override
  Future<List<AvailabilitySpecific>> getAvailabilitySpecific(
    String listingId,
  ) =>
      _availability.listSpecific(listingId);

  @override
  Future<List<BookingTimeWindow>> getBookingBlocksOverlapping(
    String listingId, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) =>
      _reservations.fetchOverlappingBlocksForListing(
        listingId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

  @override
  Future<List<Listing>> getPublishedListingsForMap({MapFilters? filters}) =>
      _listings.fetchPublishedForMap(filters: filters);

  @override
  Future<void> setAllAvailabilitySlotPrices({
    required String listingId,
    required double priceHour,
    double? priceDay,
  }) async {
    final listing = await _listings.fetchById(listingId);
    if (listing == null) return;
    await _availability.updateAllSlotPricesForListing(
      listing: listing,
      priceHour: priceHour,
      priceDay: priceDay,
    );
  }

  @override
  Future<void> updateAvailabilityWeeklySlotPrices({
    required String slotId,
    required double priceHour,
    double? priceDay,
  }) =>
      _availability.updateWeeklySlotPrices(
        slotId: slotId,
        priceHour: priceHour,
        priceDay: priceDay,
      );

  @override
  Future<AvailabilityWeekly> insertAvailabilityWeeklySlot({
    required String listingId,
    required int dayOfWeek,
    required String startTimeHhMm,
    required String endTimeHhMm,
    double priceHour = 0,
    double? priceDay,
  }) =>
      _availability.insertWeeklySlot(
        listingId: listingId,
        dayOfWeek: dayOfWeek,
        startTimeHhMm: startTimeHhMm,
        endTimeHhMm: endTimeHhMm,
        priceHour: priceHour,
        priceDay: priceDay,
      );

  @override
  Future<void> deleteAvailabilityWeeklySlot(String slotId) =>
      _availability.deleteWeeklySlot(slotId);

  @override
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
  }) =>
      _listings.insertListing(
        hostId: hostId,
        address: address,
        city: city,
        postalCode: postalCode,
        country: country,
        spotNumber: spotNumber,
        latitude: latitude,
        longitude: longitude,
        availabilityMode: availabilityMode,
      );

  @override
  Future<void> deleteListing(String listingId) =>
      _listings.deleteListing(listingId);

  @override
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
  }) =>
      _listings.updateListing(
        listingId: listingId,
        address: address,
        city: city,
        postalCode: postalCode,
        country: country,
        spotNumber: spotNumber,
        latitude: latitude,
        longitude: longitude,
        isActive: isActive,
        isPublished: isPublished,
        termsAccepted: termsAccepted,
        termsAcceptedAt: termsAcceptedAt,
        availabilityMode: availabilityMode,
      );

  @override
  Future<ListingPhoto> addListingPhotoFromLocalPath({
    required String listingId,
    required String localFilePath,
    int sortOrder = 0,
  }) =>
      _photos.uploadFromLocalPath(
        listingId: listingId,
        localFilePath: localFilePath,
        sortOrder: sortOrder,
      );

  @override
  Future<void> deleteListingPhoto(String photoId) =>
      _photos.deletePhoto(photoId);

  @override
  Future<void> reorderListingPhotos({
    required String listingId,
    required List<String> photoIdsInOrder,
  }) =>
      _photos.reorderPhotos(
        listingId: listingId,
        photoIdsInOrder: photoIdsInOrder,
      );

  @override
  Future<AvailabilitySpecific> insertAvailabilitySpecificSlot({
    required String listingId,
    required DateTime start,
    required DateTime end,
    double priceHour = 0,
    double? priceDay,
  }) =>
      _availability.insertSpecificSlot(
        listingId: listingId,
        start: start,
        end: end,
        priceHour: priceHour,
        priceDay: priceDay,
      );

  @override
  Future<void> deleteAvailabilitySpecificSlot(String slotId) =>
      _availability.deleteSpecificSlot(slotId);

  @override
  Future<void> updateAvailabilitySpecificSlotPrices({
    required String slotId,
    required double priceHour,
    double? priceDay,
  }) =>
      _availability.updateSpecificSlotPrices(
        slotId: slotId,
        priceHour: priceHour,
        priceDay: priceDay,
      );
}
