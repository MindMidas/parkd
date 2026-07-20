import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/payment_methods_remote.dart';
import '../../../core/models/payment_method_row.dart';
import 'payment_methods_repository.dart';

class SupabasePaymentMethodsRepository implements PaymentMethodsRepository {
  SupabasePaymentMethodsRepository(SupabaseClient client)
    : _remote = PaymentMethodsRemote(client);

  final PaymentMethodsRemote _remote;

  @override
  Future<List<PaymentMethodRow>> listForUser(String userId) =>
      _remote.listForUser(userId);

  @override
  Future<PaymentMethodRow> addMethod({
    required String userId,
    String? stripePaymentMethodId,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
    bool setAsDefault = false,
  }) {
    return _remote.insert(
      userId: userId,
      stripePaymentMethodId: stripePaymentMethodId,
      brand: brand,
      last4: last4,
      expMonth: expMonth,
      expYear: expYear,
      setAsDefault: setAsDefault,
    );
  }

  @override
  Future<void> setDefault({required String userId, required String id}) =>
      _remote.setDefault(userId: userId, id: id);

  @override
  Future<void> remove({required String userId, required String id}) =>
      _remote.deleteRow(userId: userId, id: id);

  @override
  Future<void> updateDisplayFields({
    required String userId,
    required String id,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
  }) => _remote.updateDisplayFields(
    userId: userId,
    id: id,
    brand: brand,
    last4: last4,
    expMonth: expMonth,
    expYear: expYear,
  );
}
