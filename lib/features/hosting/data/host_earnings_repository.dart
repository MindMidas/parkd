import '../../../core/models/host_earnings_row.dart';
import '../../../core/models/host_payment_transaction.dart';

// monthly rollups + per-payment lines for the host earnings UI
abstract class HostEarningsRepository {
  Future<List<HostEarningsRow>> listForHost(String hostId);

  // 'payments.status = succeeded' for user's reservations (newest first)
  Future<List<HostPaymentTransaction>> listSucceededTransactionsForHost(
    String hostId,
  );
}
