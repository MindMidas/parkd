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

  // Net to host is payment.amount (matches trip total_price). Service fee is on the guest bill.
  double get netToHost => payment.amount;
}
