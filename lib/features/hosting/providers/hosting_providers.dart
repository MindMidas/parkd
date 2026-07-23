import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/host_earnings_row.dart';
import '../../../core/models/host_payment_transaction.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/host_earnings_repository.dart';
import '../data/supabase_host_earnings_repository.dart';

final hostEarningsRepositoryProvider = Provider<HostEarningsRepository>((ref) {
  return SupabaseHostEarningsRepository(
    ref.watch(supabaseClientProvider),
    listingsRepository: ref.watch(listingsRepositoryProvider),
  );
});

final hostEarningsForCurrentUserProvider =
    FutureProvider<List<HostEarningsRow>>((ref) async {
      final repo = ref.watch(hostEarningsRepositoryProvider);
      final uid = ref.watch(currentSessionProvider)?.user.id;
      if (uid == null) return [];
      return repo.listForHost(uid);
    });

final hostSucceededTransactionsForCurrentUserProvider =
    FutureProvider<List<HostPaymentTransaction>>((ref) async {
      final repo = ref.watch(hostEarningsRepositoryProvider);
      final uid = ref.watch(currentSessionProvider)?.user.id;
      if (uid == null) return [];
      return repo.listSucceededTransactionsForHost(uid);
    });
