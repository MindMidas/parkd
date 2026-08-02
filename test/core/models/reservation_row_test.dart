import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/reservation_row.dart';
import 'package:parkd/core/models/reservation_status.dart';

ReservationRow _row({
  required ReservationStatus status,
  String? cancellationReason,
}) {
  return ReservationRow(
    id: 'r1',
    listingId: 'l1',
    driverId: 'd1',
    hostId: 'h1',
    startTime: DateTime.utc(2026, 8, 3, 13, 30),
    endTime: DateTime.utc(2026, 8, 3, 18, 30),
    totalPrice: 20,
    serviceFee: 0.7,
    status: status,
    cancellationReason: cancellationReason,
  );
}

void main() {
  group('ReservationRow.isCheckoutHoldNoise', () {
    test('hides abandoned checkout cancels', () {
      expect(
        _row(
          status: ReservationStatus.cancelled,
          cancellationReason: 'driver_cancelled_checkout',
        ).isCheckoutHoldNoise,
        isTrue,
      );
      expect(
        _row(
          status: ReservationStatus.cancelled,
          cancellationReason: 'checkout_expired',
        ).isCheckoutHoldNoise,
        isTrue,
      );
      expect(
        _row(
          status: ReservationStatus.cancelled,
          cancellationReason: 'driver_superseded_checkout',
        ).isCheckoutHoldNoise,
        isTrue,
      );
    });

    test('keeps real cancelled trips and completed bookings', () {
      expect(
        _row(
          status: ReservationStatus.cancelled,
          cancellationReason: 'driver_cancelled_refunded',
        ).isCheckoutHoldNoise,
        isFalse,
      );
      expect(
        _row(status: ReservationStatus.completed).isCheckoutHoldNoise,
        isFalse,
      );
      expect(
        _row(status: ReservationStatus.confirmed).isCheckoutHoldNoise,
        isFalse,
      );
    });
  });
}
