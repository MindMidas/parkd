import '../../../core/models/payment_record_status.dart';
import '../../../core/models/payment_row.dart';
import '../../../core/models/reservation_row.dart';
import '../../../core/models/reservation_status.dart';

// driver + host trip rows and checkout pairing with payments
abstract class ReservationsRepository {
  Future<(ReservationRow, PaymentRow)> createReservationWithPayment({
    required String listingId,
    required String driverId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
    required double serviceFee,
    String? paymentMethodId,
  });

  Future<ReservationRow?> getReservation(String id);

  Future<List<ReservationRow>> listDriverTrips({
    required String driverId,
    required bool activeOnly,
  });

  Future<List<ReservationRow>> listHostTrips({
    required String hostId,
    required bool activeOnly,
  });

  Future<void> updateReservationStatus(String id, ReservationStatus status);

  Future<PaymentRow?> paymentForReservation(String reservationId);

  Future<void> updatePaymentStatusForReservation(
    String reservationId,
    PaymentRecordStatus status,
  );
}
