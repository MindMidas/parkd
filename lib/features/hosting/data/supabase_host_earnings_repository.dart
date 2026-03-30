import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/host_earnings_remote.dart';
import '../../../core/supabase/payments_remote.dart';
import '../../../core/models/host_earnings_row.dart';
import '../../../core/models/host_payment_transaction.dart';
import '../../../core/models/payment_row.dart';
import '../../../core/models/reservation_row.dart';
import '../../listings/data/listings_repository.dart';
import 'host_earnings_repository.dart';

class SupabaseHostEarningsRepository implements HostEarningsRepository {
  SupabaseHostEarningsRepository(
    SupabaseClient client, {
    required ListingsRepository listingsRepository,
  })  : _earnings = HostEarningsRemote(client),
        _payments = PaymentsRemote(client),
        _listings = listingsRepository;

  final HostEarningsRemote _earnings;
  final PaymentsRemote _payments;
  final ListingsRepository _listings;

  @override
  Future<List<HostEarningsRow>> listForHost(String hostId) =>
      _earnings.fetchForHost(hostId);

  @override
  Future<List<HostPaymentTransaction>> listSucceededTransactionsForHost(
    String hostId,
  ) async {
    final rows = await _payments.fetchSucceededForHost(hostId);
    final out = <HostPaymentTransaction>[];
    for (final row in rows) {
      final nested = row['reservations'];
      if (nested is! Map) continue;
      final payJson = Map<String, dynamic>.from(row)..remove('reservations');
      final payment = PaymentRow.fromJson(payJson);
      final reservation =
          ReservationRow.fromJson(Map<String, dynamic>.from(nested));
      final listing = await _listings.getListingById(reservation.listingId);
      out.add(
        HostPaymentTransaction(
          payment: payment,
          reservation: reservation,
          listing: listing,
        ),
      );
    }
    return out;
  }
}
