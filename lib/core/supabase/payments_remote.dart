import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/payment_record_status.dart';
import '../models/payment_row.dart';

// one row per reservation on public.payments
class PaymentsRemote {
  PaymentsRemote(this._client);

  final SupabaseClient _client;

  Future<PaymentRow> insertPayment({
    required String reservationId,
    String? paymentMethodId,
    String? stripePaymentIntentId,
    required double amount,
    required double serviceFee,
    PaymentRecordStatus status = PaymentRecordStatus.pending,
  }) async {
    final row = await _client
        .from('payments')
        .insert({
          'reservation_id': reservationId,
          'payment_method_id': paymentMethodId,
          'stripe_payment_intent_id': stripePaymentIntentId,
          'amount': amount,
          'service_fee': serviceFee,
          'status': status.name,
        })
        .select()
        .single();
    return PaymentRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<PaymentRow?> fetchByReservationId(String reservationId) async {
    final row = await _client
        .from('payments')
        .select()
        .eq('reservation_id', reservationId)
        .maybeSingle();
    if (row == null) return null;
    return PaymentRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> updateStatus(String paymentId, PaymentRecordStatus status) async {
    await _client.from('payments').update({'status': status.name}).eq('id', paymentId);
  }

  Future<void> patchByReservationId(
    String reservationId, {
    String? stripePaymentIntentId,
    PaymentRecordStatus? status,
    String? paymentMethodId,
  }) async {
    final payload = <String, dynamic>{};
    if (stripePaymentIntentId != null) {
      payload['stripe_payment_intent_id'] = stripePaymentIntentId;
    }
    if (status != null) payload['status'] = status.name;
    if (paymentMethodId != null) payload['payment_method_id'] = paymentMethodId;
    if (payload.isEmpty) return;
    await _client.from('payments').update(payload).eq('reservation_id', reservationId);
  }

  // success payments where linked reservation's host is hostId
  Future<List<Map<String, dynamic>>> fetchSucceededForHost(String hostId) async {
    final rows = await _client
        .from('payments')
        .select('*, reservations!inner(*)')
        .eq('status', PaymentRecordStatus.succeeded.name)
        .eq('reservations.host_id', hostId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
