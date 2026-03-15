import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/listing.dart';
import '../../../core/models/listing_photo.dart';
import 'listings_repository.dart';

/// Returns hardcoded dummy data. Use until Supabase is wired (see database/README.md).
class DummyListingsRepository implements ListingsRepository {
  @override
  Future<List<Listing>> getMyListings(String userId) async {
    return _dummyListings;
  }

  @override
  Future<Listing?> getListingById(String id) async {
    try {
      return _dummyListings.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ListingPhoto>> getListingPhotos(String listingId) async {
    return [
      ListingPhoto(
        id: 'photo-1',
        listingId: listingId,
        photoUrl: '', // placeholder; UI uses icon
        sortOrder: 0,
      ),
    ];
  }

  @override
  Future<List<AvailabilityWeekly>> getAvailabilityWeekly(String listingId) async {
    if (listingId != 'listing-1') return [];
    return _dummyWeeklySlots;
  }

  @override
  Future<List<AvailabilitySpecific>> getAvailabilitySpecific(
    String listingId,
  ) async {
    return _dummySpecificSlots;
  }

  static final _dummyListings = [
    Listing(
      id: 'listing-1',
      hostId: 'host-1',
      address: '25 Macdonell Street',
      city: 'Guelph',
      postalCode: 'ON N1L 0M5',
      spotNumber: '345',
      latitude: 43.5448,
      longitude: -80.2482,
      priceHour: 10,
      priceDay: 30,
    ),
    Listing(
      id: 'listing-2',
      hostId: 'host-1',
      address: '1291 Gordon Street',
      city: 'Guelph',
      postalCode: 'ON N1W 0M5',
      spotNumber: '1',
      latitude: 43.5320,
      longitude: -80.2260,
      priceHour: 10,
      priceDay: 30,
    ),
  ];

  static final _dummyWeeklySlots = [
    AvailabilityWeekly(
      id: 'weekly-1',
      listingId: 'listing-1',
      dayOfWeek: 1, // Mon
      startTime: '09:15',
      endTime: '13:00',
    ),
    AvailabilityWeekly(
      id: 'weekly-2',
      listingId: 'listing-1',
      dayOfWeek: 1,
      startTime: '15:00',
      endTime: '18:00',
    ),
    AvailabilityWeekly(
      id: 'weekly-3',
      listingId: 'listing-1',
      dayOfWeek: 2, // Tue
      startTime: '08:30',
      endTime: '15:00',
    ),
  ];

  static final _dummySpecificSlots = [
    AvailabilitySpecific(
      id: 'spec-1',
      listingId: 'listing-1',
      startDatetime: DateTime(2026, 9, 15, 9, 0),
      endDatetime: DateTime(2026, 9, 20, 15, 0),
    ),
    AvailabilitySpecific(
      id: 'spec-2',
      listingId: 'listing-1',
      startDatetime: DateTime(2026, 10, 3, 10, 0),
      endDatetime: DateTime(2026, 10, 7, 18, 0),
    ),
  ];
}
