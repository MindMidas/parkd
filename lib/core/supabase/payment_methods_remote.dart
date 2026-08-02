import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/payment_method_row.dart';

// CRUD for public.payment_methods. Stripe ID is optional while card setup runs.
class PaymentMethodsRemote {
  PaymentMethodsRemote(this._client);

  final SupabaseClient _client;

  Future<List<PaymentMethodRow>> listForUser(String userId) async {
    final rows = await _client
        .from('payment_methods')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (e) => PaymentMethodRow.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<PaymentMethodRow> insert({
    required String userId,
    String? stripePaymentMethodId,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
    bool setAsDefault = false,
  }) async {
    if (setAsDefault) {
      await _client
          .from('payment_methods')
          .update({'is_default': false})
          .eq('user_id', userId);
    }
    final row = await _client
        .from('payment_methods')
        .insert({
          'user_id': userId,
          'stripe_payment_method_id': stripePaymentMethodId,
          'brand': brand,
          'last4': last4,
          'exp_month': expMonth,
          'exp_year': expYear,
          'is_default': setAsDefault,
        })
        .select()
        .single();
    return PaymentMethodRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> setDefault({required String userId, required String id}) async {
    await _client
        .from('payment_methods')
        .update({'is_default': false})
        .eq('user_id', userId);
    await _client
        .from('payment_methods')
        .update({'is_default': true})
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> deleteRow({required String userId, required String id}) async {
    await _client
        .from('payment_methods')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<void> updateDisplayFields({
    required String userId,
    required String id,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
  }) async {
    final payload = <String, dynamic>{};
    if (brand != null) payload['brand'] = brand;
    if (last4 != null) payload['last4'] = last4;
    if (expMonth != null) payload['exp_month'] = expMonth;
    if (expYear != null) payload['exp_year'] = expYear;
    if (payload.isEmpty) return;
    await _client
        .from('payment_methods')
        .update(payload)
        .eq('id', id)
        .eq('user_id', userId);
  }
}
