import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import 'stripe_checkout_remote.dart';

final stripeCheckoutRemoteProvider = Provider<StripeCheckoutRemote>((ref) {
  return StripeCheckoutRemote(ref.watch(supabaseClientProvider));
});
