import 'payment_record_status.dart';

// Mirrors public.payments
class PaymentRow {
  const PaymentRow({
    required this.id,
    required this.reservationId,
    this.paymentMethodId,
    this.stripePaymentIntentId,
    required this.amount,
    required this.serviceFee,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String reservationId;
  final String? paymentMethodId;
  final String? stripePaymentIntentId;
  final double amount;
  final double serviceFee;
  final PaymentRecordStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static PaymentRow fromJson(Map<String, dynamic> json) {
    return PaymentRow(
      id: json['id'] as String,
      reservationId: json['reservation_id'] as String,
      paymentMethodId: json['payment_method_id'] as String?,
      stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      serviceFee: (json['service_fee'] as num).toDouble(),
      status:
          PaymentRecordStatus.fromWire(json['status'] as String?) ??
          PaymentRecordStatus.pending,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
