import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/payment_row.dart';

/// One row per reservation on public.payments
class PaymentsRemote {
  PaymentsRemote(this._client);

  final SupabaseClient _client;

  Future<PaymentRow?> fetchByReservationId(String reservationId) async {
    final row = await _client
        .from('payments')
        .select()
        .eq('reservation_id', reservationId)
        .maybeSingle();
    if (row == null) return null;
    return PaymentRow.fromJson(Map<String, dynamic>.from(row));
  }

  /// Succeeded payments where the linked reservation’s host is [hostId]
  Future<List<Map<String, dynamic>>> fetchSucceededForHost(
    String hostId,
  ) async {
    final rows = await _client
        .from('payments')
        .select('*, reservations!inner(*)')
        .eq('status', 'succeeded')
        .eq('reservations.host_id', hostId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
