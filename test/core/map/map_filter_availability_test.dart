import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/map/map_filter_availability.dart';
import 'package:parkd/core/models/availability_specific.dart';
import 'package:parkd/core/models/availability_weekly.dart';
import 'package:parkd/core/models/booking_time_window.dart';
import 'package:parkd/core/models/listing.dart';

void main() {
  const listingId = 'listing-1';
  final monday = DateTime(2026, 7, 20);
  const weeklyListing = Listing(
    id: listingId,
    hostId: 'host-1',
    address: 'Parking in Guelph',
    city: 'Guelph',
    latitude: 43.54,
    longitude: -80.25,
    availabilityMode: ListingAvailabilityMode.weekly,
  );
  const weekly = [
    AvailabilityWeekly(
      id: 'weekly-1',
      listingId: listingId,
      dayOfWeek: 1,
      startTime: '09:00',
      endTime: '17:00',
    ),
  ];

  test('matches a weekly listing open for the complete requested window', () {
    final matches = listingMatchesMapAvailabilityWindow(
      listing: weeklyListing,
      weekly: weekly,
      specific: const [],
      bookings: const [],
      rangeStartDay: monday,
      rangeEndDay: monday,
      startMinutes: 10 * 60,
      endMinutes: 12 * 60,
    );

    expect(matches, isTrue);
  });

  test('rejects host closure and overlapping busy windows', () {
    final outsideHostHours = listingMatchesMapAvailabilityWindow(
      listing: weeklyListing,
      weekly: weekly,
      specific: const [],
      bookings: const [],
      rangeStartDay: monday,
      rangeEndDay: monday,
      startMinutes: 8 * 60,
      endMinutes: 10 * 60,
    );
    final overlapsBooking = listingMatchesMapAvailabilityWindow(
      listing: weeklyListing,
      weekly: weekly,
      specific: const [],
      bookings: [
        BookingTimeWindow(
          start: DateTime(2026, 7, 20, 10, 30),
          end: DateTime(2026, 7, 20, 11),
        ),
      ],
      rangeStartDay: monday,
      rangeEndDay: monday,
      startMinutes: 10 * 60,
      endMinutes: 12 * 60,
    );

    expect(outsideHostHours, isFalse);
    expect(overlapsBooking, isFalse);
  });

  test('allows a busy window that only touches the requested boundary', () {
    final matches = listingMatchesMapAvailabilityWindow(
      listing: weeklyListing,
      weekly: weekly,
      specific: const [],
      bookings: [
        BookingTimeWindow(
          start: DateTime(2026, 7, 20, 9),
          end: DateTime(2026, 7, 20, 10),
        ),
      ],
      rangeStartDay: monday,
      rangeEndDay: monday,
      startMinutes: 10 * 60,
      endMinutes: 12 * 60,
    );

    expect(matches, isTrue);
  });

  test('matches a specific-date listing that covers the window', () {
    const listing = Listing(
      id: listingId,
      hostId: 'host-1',
      address: 'Parking in Guelph',
      city: 'Guelph',
      latitude: 43.54,
      longitude: -80.25,
      availabilityMode: ListingAvailabilityMode.specific,
    );
    final matches = listingMatchesMapAvailabilityWindow(
      listing: listing,
      weekly: const [],
      specific: [
        AvailabilitySpecific(
          id: 'specific-1',
          listingId: listingId,
          startDatetime: DateTime(2026, 7, 20, 9),
          endDatetime: DateTime(2026, 7, 20, 17),
        ),
      ],
      bookings: const [],
      rangeStartDay: monday,
      rangeEndDay: monday,
      startMinutes: 10 * 60,
      endMinutes: 12 * 60,
    );

    expect(matches, isTrue);
  });
}
