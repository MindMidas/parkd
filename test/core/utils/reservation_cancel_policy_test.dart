import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/utils/reservation_cancel_policy.dart';

void main() {
  group('reservationCancelIsRefundable', () {
    final now = DateTime.utc(2026, 7, 24, 12);

    test('refunds when more than 2 hours remain', () {
      expect(
        reservationCancelIsRefundable(
          DateTime.utc(2026, 7, 24, 15),
          now: now,
        ),
        isTrue,
      );
    });

    test('no refund inside 2 hour window', () {
      expect(
        reservationCancelIsRefundable(
          DateTime.utc(2026, 7, 24, 13, 30),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('reservationIsDriverCancellable', () {
    final now = DateTime.utc(2026, 7, 24, 12);

    test('confirmed upcoming is cancellable', () {
      expect(
        reservationIsDriverCancellable(
          DateTime.utc(2026, 7, 24, 13),
          status: 'confirmed',
          now: now,
        ),
        isTrue,
      );
    });

    test('started or non-confirmed is not cancellable', () {
      expect(
        reservationIsDriverCancellable(
          DateTime.utc(2026, 7, 24, 11),
          status: 'confirmed',
          now: now,
        ),
        isFalse,
      );
      expect(
        reservationIsDriverCancellable(
          DateTime.utc(2026, 7, 24, 15),
          status: 'active',
          now: now,
        ),
        isFalse,
      );
    });
  });
}
