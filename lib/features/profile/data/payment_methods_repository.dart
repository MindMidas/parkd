import '../../../core/models/payment_method_row.dart';

// saved cards for checkout and settings
abstract class PaymentMethodsRepository {
  Future<List<PaymentMethodRow>> listForUser(String userId);

  Future<PaymentMethodRow> addMethod({
    required String userId,
    String? stripePaymentMethodId,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
    bool setAsDefault,
  });

  Future<void> setDefault({required String userId, required String id});

  Future<void> remove({required String userId, required String id});

  Future<void> updateDisplayFields({
    required String userId,
    required String id,
    String? brand,
    String? last4,
    int? expMonth,
    int? expYear,
  });
}
