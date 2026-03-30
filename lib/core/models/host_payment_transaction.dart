import 'listing.dart';
import 'payment_row.dart';
import 'reservation_row.dart';

// Host payout row: payment, reservation, listing.
class HostPaymentTransaction {
  const HostPaymentTransaction({
    required this.payment,
    required this.reservation,
    this.listing,
  });

  final PaymentRow payment;
  final ReservationRow reservation;
  final Listing? listing;

  // host's parking earnings: [payment.amount] matches reservation 'total_price'
  // [payment.serviceFee] is charged to driver on top, not taken from this
  double get netToHost => payment.amount;
}
