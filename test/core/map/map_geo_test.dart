import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/map/map_approximate_clusters.dart';
import 'package:parkd/core/map/map_geo.dart';
import 'package:parkd/core/models/listing.dart';

void main() {
  group('approximateListingAreaRing', () {
    test('uses a short-walk parking privacy radius', () {
      expect(kApproximateListingAreaRadiusMeters, closeTo(250, 1));
      const lat = 43.51;
      const lon = -80.20;
      final ring = approximateListingAreaRing(
        latitude: lat,
        longitude: lon,
        radiusMeters: kApproximateListingAreaRadiusMeters,
        steps: 32,
      );

      expect(ring.length, 33);
      expect(ring.first[0], closeTo(ring.last[0], 1e-9));
      expect(ring.first[1], closeTo(ring.last[1], 1e-9));

      final north = ring[0];
      expect(
        distanceKmBetween(lat, lon, north[1], north[0]) * 1000,
        closeTo(kApproximateListingAreaRadiusMeters, 3),
      );
    });

    test('obfuscates the marker off the curb by a stable offset', () {
      final a = obfuscateApproximateMapCenter(
        listingId: '0190cb27-0fbb-4e74-b433-fe9d97cadf86',
        latitude: 43.514,
        longitude: -80.201,
      );
      final b = obfuscateApproximateMapCenter(
        listingId: '0190cb27-0fbb-4e74-b433-fe9d97cadf86',
        latitude: 43.514,
        longitude: -80.201,
      );
      expect(a.latitude, b.latitude);
      expect(a.longitude, b.longitude);
      expect(
        distanceKmBetween(43.514, -80.201, a.latitude, a.longitude) * 1000,
        closeTo(kApproximateMarkerOffsetMeters, 3),
      );
    });
  });

  group('clusterApproximateListingsByCell', () {
    test('stacks nearby approximate listings into one cell', () {
      final clusters = clusterApproximateListingsByCell([
        Listing(
          id: 'a',
          hostId: 'h1',
          address: 'Parking in Guelph',
          city: 'Guelph',
          latitude: 43.51,
          longitude: -80.20,
          isApproximateLocation: true,
          minHourlyPrice: 10,
        ),
        Listing(
          id: 'b',
          hostId: 'h2',
          address: 'Parking in Guelph',
          city: 'Guelph',
          latitude: 43.51,
          longitude: -80.20,
          isApproximateLocation: true,
          minHourlyPrice: 12,
        ),
        Listing(
          id: 'exact',
          hostId: 'h3',
          address: '1 Main St',
          city: 'Guelph',
          latitude: 43.51,
          longitude: -80.20,
          isApproximateLocation: false,
        ),
      ]);

      expect(clusters.length, 1);
      expect(clusters.values.single.map((l) => l.id), ['a', 'b']);
    });
  });
}
