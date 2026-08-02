import 'listing.dart';
import 'payment_row.dart';
import 'reservation_row.dart';

// Host earnings line: succeeded payment + reservation + listing (optional if deleted)
class HostPaymentTransaction {
  const HostPaymentTransaction({
    required this.payment,
    required this.reservation,
    this.listing,
  });

  final PaymentRow payment;
  final ReservationRow reservation;
  final Listing? listing;

  double get netToHost => payment.amount;
}
