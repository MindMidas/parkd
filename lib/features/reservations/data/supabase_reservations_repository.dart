import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/payments_remote.dart';
import '../../../core/supabase/reservations_remote.dart';
import '../../../core/models/payment_record_status.dart';
import '../../../core/models/payment_row.dart';
import '../../../core/models/reservation_row.dart';
import '../../../core/models/reservation_status.dart';
import 'reservations_repository.dart';

class SupabaseReservationsRepository implements ReservationsRepository {
  SupabaseReservationsRepository(SupabaseClient client)
      : _res = ReservationsRemote(client),
        _pay = PaymentsRemote(client);

  final ReservationsRemote _res;
  final PaymentsRemote _pay;

  @override
  Future<(ReservationRow, PaymentRow)> createReservationWithPayment({
    required String listingId,
    required String driverId,
    required DateTime startTime,
    required DateTime endTime,
    required double totalPrice,
    required double serviceFee,
    String? paymentMethodId,
  }) async {
    final r = await _res.insertReservation(
      listingId: listingId,
      driverId: driverId,
      startTime: startTime,
      endTime: endTime,
      totalPrice: totalPrice,
      serviceFee: serviceFee,
    );
    final p = await _pay.insertPayment(
      reservationId: r.id,
      paymentMethodId: paymentMethodId,
      amount: totalPrice,
      serviceFee: serviceFee,
    );
    return (r, p);
  }

  @override
  Future<ReservationRow?> getReservation(String id) => _res.fetchById(id);

  @override
  Future<List<ReservationRow>> listDriverTrips({
    required String driverId,
    required bool activeOnly,
  }) =>
      _res.fetchForDriver(driverId, activeOnly: activeOnly);

  @override
  Future<List<ReservationRow>> listHostTrips({
    required String hostId,
    required bool activeOnly,
  }) =>
      _res.fetchForHost(hostId, activeOnly: activeOnly);

  @override
  Future<void> updateReservationStatus(String id, ReservationStatus status) =>
      _res.updateStatus(id, status);

  @override
  Future<PaymentRow?> paymentForReservation(String reservationId) =>
      _pay.fetchByReservationId(reservationId);

  @override
  Future<void> updatePaymentStatusForReservation(
    String reservationId,
    PaymentRecordStatus status,
  ) async {
    final p = await _pay.fetchByReservationId(reservationId);
    if (p == null) return;
    await _pay.updateStatus(p.id, status);
  }
}
