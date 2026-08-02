import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import 'stripe_checkout_remote.dart';
import 'stripe_connect_remote.dart';

final stripeCheckoutRemoteProvider = Provider<StripeCheckoutRemote>((ref) {
  return StripeCheckoutRemote(ref.watch(supabaseClientProvider));
});

final stripeConnectRemoteProvider = Provider<StripeConnectRemote>((ref) {
  return StripeConnectRemote(ref.watch(supabaseClientProvider));
});

final stripeConnectStatusProvider =
    FutureProvider.autoDispose<StripeConnectStatus>((ref) async {
      return ref.watch(stripeConnectRemoteProvider).fetchStatus();
    });
