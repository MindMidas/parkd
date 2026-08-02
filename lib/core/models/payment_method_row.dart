// Mirrors public.payment_methods — use for repo/remote layers
class PaymentMethodRow {
  const PaymentMethodRow({
    required this.id,
    required this.userId,
    this.stripePaymentMethodId,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    required this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String? stripePaymentMethodId;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static PaymentMethodRow fromJson(Map<String, dynamic> json) {
    return PaymentMethodRow(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      stripePaymentMethodId: json['stripe_payment_method_id'] as String?,
      brand: json['brand'] as String?,
      last4: json['last4'] as String?,
      expMonth: json['exp_month'] as int?,
      expYear: json['exp_year'] as int?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
