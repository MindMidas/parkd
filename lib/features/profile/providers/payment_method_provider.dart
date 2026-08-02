import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/payment_method_row.dart';
import 'profile_providers.dart';

// Explicit checkout/settings choice; `null` falls back to default row or first card
class SelectedPaymentMethodIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedPaymentMethodIdProvider =
    NotifierProvider<SelectedPaymentMethodIdNotifier, String?>(
      SelectedPaymentMethodIdNotifier.new,
    );

final effectiveSelectedPaymentMethodIdProvider = Provider<String?>((ref) {
  final methods = ref.watch(paymentMethodsForCurrentUserProvider);
  final manualId = ref.watch(selectedPaymentMethodIdProvider);
  return methods.maybeWhen(
    data: (list) {
      if (list.isEmpty) return null;
      if (manualId != null && list.any((m) => m.id == manualId)) {
        return manualId;
      }
      for (final m in list) {
        if (m.isDefault) return m.id;
      }
      return list.first.id;
    },
    orElse: () => null,
  );
});

final selectedPaymentMethodProvider = Provider<PaymentMethodRow?>((ref) {
  final methods = ref.watch(paymentMethodsForCurrentUserProvider);
  final id = ref.watch(effectiveSelectedPaymentMethodIdProvider);
  return methods.maybeWhen(
    data: (list) {
      if (id == null) return null;
      for (final m in list) {
        if (m.id == id) return m;
      }
      return null;
    },
    orElse: () => null,
  );
});
