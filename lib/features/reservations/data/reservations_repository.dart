import '../../../core/models/payment_row.dart';
import '../../../core/models/reservation_row.dart';

/// Driver + host trip rows and checkout pairing with payments
abstract class ReservationsRepository {
  Future<ReservationRow?> getReservation(String id);

  Future<List<ReservationRow>> listDriverTrips({
    required String driverId,
    required bool activeOnly,
  });

  Future<List<ReservationRow>> listHostTrips({
    required String hostId,
    required bool activeOnly,
  });

  /// The only reservation state transition initiated directly by a client.
  /// Creation, pricing, payment confirmation, activation, and completion are
  /// server-owned operations.
  Future<void> cancelCheckoutHold(String id);

  Future<PaymentRow?> paymentForReservation(String reservationId);
}
