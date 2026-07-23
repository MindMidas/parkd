import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/map/map_filters.dart';
import 'package:parkd/core/map/map_geo.dart';

void main() {
  group('MapFilters', () {
    test('builds a valid single-day availability window', () {
      final filters = MapFilters(
        availabilityFilterEnabled: true,
        availRangeStart: DateTime(2026, 7, 20),
        availRangeEnd: DateTime(2026, 7, 20),
        availStartMinutes: 10 * 60,
        availEndMinutes: 12 * 60,
      );

      expect(filters.availabilityWindowStart, DateTime(2026, 7, 20, 10));
      expect(filters.availabilityWindowEnd, DateTime(2026, 7, 20, 12));
      expect(filters.hasValidAvailabilityWindow, isTrue);
    });

    test('copyWith preserves the selected availability range', () {
      final start = DateTime(2026, 7, 20);
      final end = DateTime(2026, 7, 21);
      final filters = MapFilters(
        availRangeStart: start,
        availRangeEnd: end,
      ).copyWith(proximityEnabled: true, proximityRadiusKm: 5);

      expect(filters.availRangeStart, start);
      expect(filters.availRangeEnd, end);
      expect(filters.proximityEnabled, isTrue);
      expect(filters.proximityRadiusKm, 5);
    });

    test('rejects a same-day window whose end is not after its start', () {
      final filters = MapFilters(
        availabilityFilterEnabled: true,
        availRangeStart: DateTime(2026, 7, 20),
        availRangeEnd: DateTime(2026, 7, 20),
        availStartMinutes: 17 * 60,
        availEndMinutes: 9 * 60,
      );

      expect(filters.hasValidAvailabilityWindow, isFalse);
    });
  });

  group('distanceKmBetween', () {
    test('returns zero for the same point', () {
      expect(distanceKmBetween(43.5448, -80.2482, 43.5448, -80.2482), 0);
    });

    test('returns a symmetric haversine distance', () {
      final forward = distanceKmBetween(43.5448, -80.2482, 43.6532, -79.3832);
      final reverse = distanceKmBetween(43.6532, -79.3832, 43.5448, -80.2482);

      expect(forward, closeTo(reverse, 0.000001));
      expect(forward, greaterThan(60));
      expect(forward, lessThan(90));
    });
  });
}
