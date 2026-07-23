import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/payments_remote.dart';
import '../../../core/supabase/reservations_remote.dart';
import '../../../core/models/payment_row.dart';
import '../../../core/models/reservation_row.dart';
import 'reservations_repository.dart';

class SupabaseReservationsRepository implements ReservationsRepository {
  SupabaseReservationsRepository(SupabaseClient client)
    : _res = ReservationsRemote(client),
      _pay = PaymentsRemote(client);

  final ReservationsRemote _res;
  final PaymentsRemote _pay;

  @override
  Future<ReservationRow?> getReservation(String id) => _res.fetchById(id);

  @override
  Future<List<ReservationRow>> listDriverTrips({
    required String driverId,
    required bool activeOnly,
  }) => _res.fetchForDriver(driverId, activeOnly: activeOnly);

  @override
  Future<List<ReservationRow>> listHostTrips({
    required String hostId,
    required bool activeOnly,
  }) => _res.fetchForHost(hostId, activeOnly: activeOnly);

  @override
  Future<void> cancelCheckoutHold(String id) => _res.cancelCheckoutHold(id);

  @override
  Future<PaymentRow?> paymentForReservation(String reservationId) =>
      _pay.fetchByReservationId(reservationId);
}
