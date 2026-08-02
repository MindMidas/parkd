import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/map/listing_next_available.dart';
import 'package:parkd/core/models/availability_specific.dart';
import 'package:parkd/core/models/availability_weekly.dart';
import 'package:parkd/core/models/booking_time_window.dart';
import 'package:parkd/core/models/listing.dart';

void main() {
  const listingId = 'listing-1';
  final now = DateTime(2026, 7, 30, 12);

  Listing specificListing(List<AvailabilitySpecific> specific) {
    return Listing(
      id: listingId,
      hostId: 'host-1',
      address: 'Parking in Guelph',
      city: 'Guelph',
      latitude: 43.54,
      longitude: -80.25,
      availabilityMode: ListingAvailabilityMode.specific,
      publicSpecificAvailability: specific,
    );
  }

  Listing weeklyListing(List<AvailabilityWeekly> weekly) {
    return Listing(
      id: listingId,
      hostId: 'host-1',
      address: 'Parking in Guelph',
      city: 'Guelph',
      latitude: 43.54,
      longitude: -80.25,
      availabilityMode: ListingAvailabilityMode.weekly,
      publicWeeklyAvailability: weekly,
    );
  }

  test('specific listing with only past windows is not discoverable', () {
    final listing = specificListing([
      AvailabilitySpecific(
        id: 's1',
        listingId: listingId,
        startDatetime: DateTime(2026, 7, 20, 9),
        endDatetime: DateTime(2026, 7, 20, 17),
      ),
    ]);
    expect(
      listingHasDiscoverableAvailability(
        listing: listing,
        now: now,
        bookings: const [],
      ),
      isFalse,
    );
  });

  test('specific listing with future gap is discoverable', () {
    final listing = specificListing([
      AvailabilitySpecific(
        id: 's1',
        listingId: listingId,
        startDatetime: DateTime(2026, 7, 31, 9),
        endDatetime: DateTime(2026, 7, 31, 17),
      ),
    ]);
    expect(
      listingHasDiscoverableAvailability(
        listing: listing,
        now: now,
        bookings: const [],
      ),
      isTrue,
    );
  });

  test('specific listing fully booked in remaining window is hidden', () {
    final start = DateTime(2026, 7, 30, 13);
    final end = DateTime(2026, 7, 30, 15);
    final listing = specificListing([
      AvailabilitySpecific(
        id: 's1',
        listingId: listingId,
        startDatetime: start,
        endDatetime: end,
      ),
    ]);
    expect(
      listingHasDiscoverableAvailability(
        listing: listing,
        now: now,
        bookings: [BookingTimeWindow(start: start, end: end)],
      ),
      isFalse,
    );
  });

  test('specific listing reappears when a booking gap opens', () {
    final start = DateTime(2026, 7, 30, 13);
    final end = DateTime(2026, 7, 30, 17);
    final listing = specificListing([
      AvailabilitySpecific(
        id: 's1',
        listingId: listingId,
        startDatetime: start,
        endDatetime: end,
      ),
    ]);
    expect(
      listingHasDiscoverableAvailability(
        listing: listing,
        now: now,
        bookings: [
          BookingTimeWindow(
            start: start,
            end: DateTime(2026, 7, 30, 14),
          ),
        ],
      ),
      isTrue,
    );
  });

  test('weekly listing stays discoverable while schedule exists', () {
    final listing = weeklyListing(const [
      AvailabilityWeekly(
        id: 'w1',
        listingId: listingId,
        dayOfWeek: 4,
        startTime: '09:00',
        endTime: '17:00',
      ),
    ]);
    expect(
      listingHasDiscoverableAvailability(
        listing: listing,
        now: now,
        bookings: [
          BookingTimeWindow(
            start: DateTime(2026, 7, 30, 9),
            end: DateTime(2026, 7, 30, 17),
          ),
        ],
      ),
      isTrue,
    );
  });

  test('listingIsExpiredSpecific is true only for past date windows', () {
    expect(
      listingIsExpiredSpecific(
        specificListing([
          AvailabilitySpecific(
            id: 's1',
            listingId: listingId,
            startDatetime: DateTime(2026, 7, 20, 9),
            endDatetime: DateTime(2026, 7, 20, 17),
          ),
        ]),
        now: now,
      ),
      isTrue,
    );
    expect(
      listingIsExpiredSpecific(
        specificListing([
          AvailabilitySpecific(
            id: 's1',
            listingId: listingId,
            startDatetime: DateTime(2026, 7, 31, 9),
            endDatetime: DateTime(2026, 7, 31, 17),
          ),
        ]),
        now: now,
      ),
      isFalse,
    );
    expect(
      listingIsExpiredSpecific(
        weeklyListing(const [
          AvailabilityWeekly(
            id: 'w1',
            listingId: listingId,
            dayOfWeek: 4,
            startTime: '09:00',
            endTime: '17:00',
          ),
        ]),
        now: now,
      ),
      isFalse,
    );
  });
}
