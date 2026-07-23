import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/listing.dart';

void main() {
  group('Listing', () {
    test('parses and serializes listing rows', () {
      final listing = Listing.fromJson({
        'id': 'listing-id',
        'host_id': 'host-id',
        'address': '1 Main St',
        'city': 'Guelph',
        'postal_code': 'N1G 2W1',
        'country': 'Canada',
        'spot_number': 'A',
        'latitude': 43.5448,
        'longitude': -80.2482,
        'availability_mode': ListingAvailabilityMode.specific,
        'is_active': true,
        'is_published': true,
        'terms_accepted': true,
        'terms_accepted_at': '2026-01-01T12:00:00.000Z',
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-02T12:00:00.000Z',
        'hero_photo_url': 'https://example.com/photo.jpg',
      });

      expect(listing.id, 'listing-id');
      expect(listing.isSpecificAvailability, isTrue);
      expect(listing.spotLabel, 'Spot #A');
      expect(listing.localityLine, 'Guelph, Canada, N1G 2W1');
      expect(
        listing.toJson()['hero_photo_url'],
        'https://example.com/photo.jpg',
      );
    });

    test('omits blank spot and hero labels', () {
      final listing = Listing.fromJson({
        'id': 'listing-id',
        'host_id': 'host-id',
        'address': '1 Main St',
        'city': 'Guelph',
        'latitude': 43.5448,
        'longitude': -80.2482,
        'spot_number': '',
        'hero_photo_url': '   ',
      });

      expect(listing.spotLabel, isNull);
      expect(listing.heroPhotoUrl, isNull);
      expect(listing.isWeeklyAvailability, isTrue);
    });

    test('parses the privacy-safe public map projection', () {
      final listing = Listing.fromJson({
        'id': 'listing-id',
        'host_id': 'host-id',
        'display_name': 'Parking in Guelph',
        'city': 'Guelph',
        'country': 'Canada',
        'postal_area': 'N1G',
        'approximate_latitude': 43.54,
        'approximate_longitude': -80.25,
        'availability_mode': ListingAvailabilityMode.weekly,
        'is_active': true,
        'is_published': true,
        'min_hourly_price': 3.5,
        'min_daily_price': 18,
        'weekly_availability': [
          {
            'id': 'weekly-id',
            'day_of_week': 1,
            'start_time': '09:00:00',
            'end_time': '17:00:00',
            'price_hour': 3.5,
            'price_day': 18,
          },
        ],
        'specific_availability': <Map<String, dynamic>>[],
      });

      expect(listing.isApproximateLocation, isTrue);
      expect(listing.locationSharing, ListingLocationSharing.general);
      expect(listing.revealsExactStreetAddress, isFalse);
      expect(listing.addressLine, 'Parking in Guelph');
      expect(listing.approximateAreaHeadline, 'Guelph, Canada');
      expect(listing.townCountryLine, 'Guelph, Canada');
      expect(listing.localityLine, 'Guelph, Canada, N1G');
      expect(listing.spotLabel, isNull);
      expect(listing.latitude, 43.54);
      expect(listing.minHourlyPrice, 3.5);
      expect(listing.publicWeeklyAvailability.single.listingId, 'listing-id');
      expect(listing.publicWeeklyAvailability.single.startTime, '09:00');
    });

    test('parses specific location sharing on a public card', () {
      final listing = Listing.fromJson({
        'id': 'listing-id',
        'host_id': 'host-id',
        'display_name': 'Parking in Guelph',
        'city': 'Guelph',
        'location_sharing': 'specific',
        'approximate_latitude': 43.5141572,
        'approximate_longitude': -80.2005685,
        'is_active': true,
        'is_published': true,
        'min_hourly_price': 10,
      });
      expect(listing.locationSharing, ListingLocationSharing.specific);
      expect(listing.isApproximateLocation, isFalse);
      expect(listing.revealsExactStreetAddress, isFalse);
    });

    test('copyWith can restore exact host coordinates on a public card', () {
      final card = Listing.fromJson({
        'id': 'listing-id',
        'host_id': 'host-id',
        'display_name': 'Parking in Guelph',
        'city': 'Guelph',
        'approximate_latitude': 43.51,
        'approximate_longitude': -80.2,
        'is_active': true,
        'is_published': true,
        'min_hourly_price': 10,
      });
      final hostView = card.copyWith(
        address: '1291 Gordon Street',
        latitude: 43.5141572,
        longitude: -80.2005685,
        isApproximateLocation: false,
      );

      expect(hostView.addressLine, '1291 Gordon Street');
      expect(hostView.latitude, 43.5141572);
      expect(hostView.longitude, -80.2005685);
      expect(hostView.isApproximateLocation, isFalse);
      expect(hostView.minHourlyPrice, 10);
    });
  });
}
