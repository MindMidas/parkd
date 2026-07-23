import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/reservation_pricing.dart';

void main() {
  group('ReservationPricing', () {
    test('rounds service fee to cents', () {
      expect(ReservationPricing.serviceFeeForSubtotal(10), 0.35);
      expect(ReservationPricing.serviceFeeForSubtotal(10.01), 0.35);
    });

    test('prices short bookings using a ten-minute minimum and increments', () {
      expect(
        ReservationPricing.computeSubtotal(
          rawMinutes: 5,
          hourlyRate: 12,
          dailyRate: 60,
        ),
        2,
      );
      expect(
        ReservationPricing.computeSubtotal(
          rawMinutes: 25,
          hourlyRate: 12,
          dailyRate: 60,
        ),
        6,
      );
    });

    test('prices hourly bookings with a minimum ten-minute remainder', () {
      expect(
        ReservationPricing.computeSubtotal(
          rawMinutes: 61,
          hourlyRate: 12,
          dailyRate: 60,
        ),
        14,
      );
    });

    test('uses cheaper daily pricing for long bookings', () {
      expect(
        ReservationPricing.computeSubtotal(
          rawMinutes: 25 * 60,
          hourlyRate: 12,
          dailyRate: 60,
        ),
        72,
      );
    });

    test('formats duration labels', () {
      expect(ReservationPricing.formatDurationLabel(0), '');
      expect(ReservationPricing.formatDurationLabel(45), '45 mins');
      expect(ReservationPricing.formatDurationLabel(90), '1 hour and 30 mins');
      expect(
        ReservationPricing.formatDurationLabel(25 * 60),
        '1 day and 1 hour',
      );
    });
  });
}
