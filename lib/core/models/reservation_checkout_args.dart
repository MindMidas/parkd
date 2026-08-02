class ReservationCheckoutArgs {
  const ReservationCheckoutArgs({
    required this.listingId,
    required this.startDateTime,
    required this.endDateTime,
    required this.subtotal,
    required this.serviceFee,
    required this.latitude,
    required this.longitude,
    this.paymentMethodId,
  });

  final String listingId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final double subtotal;
  final double serviceFee;
  final double latitude;
  final double longitude;

  final String? paymentMethodId;

  double get total => subtotal + serviceFee;
}
