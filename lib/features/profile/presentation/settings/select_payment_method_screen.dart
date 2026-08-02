import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/payment_method_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/payment_method_provider.dart';
import '../../providers/profile_providers.dart';
import 'add_card_screen.dart';

// Tap a pill → set default id → pop. Empty state / footer can add a card.
class SelectPaymentMethodScreen extends ConsumerWidget {
  const SelectPaymentMethodScreen({super.key});

  static String _brand(PaymentMethodRow m) => m.brand ?? 'Card';
  static String _last4(PaymentMethodRow m) => m.last4 ?? '••••';

  void _openAddCard(BuildContext context) {
    Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => const AddCardScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsForCurrentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Payment method', showBack: true),
      body: Column(
        children: [
          Expanded(
            child: AppAsyncBody(
              value: methodsAsync,
              errorTitle: 'Could not load cards.',
              isEmpty: (methods) => methods.isEmpty,
              emptyTitle: 'No saved cards',
              emptyMessage: 'Add a card to pay for this reservation.',
              emptyActionLabel: 'Add card',
              onEmptyAction: () => _openAddCard(context),
              data: (methods) {
                final selectedId =
                    ref.watch(effectiveSelectedPaymentMethodIdProvider);
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.lg,
                  ),
                  itemCount: methods.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final m = methods[i];
                    final selected = m.id == selectedId;
                    return AppPaymentMethodPill(
                      brand: _brand(m),
                      lastFour: _last4(m),
                      selected: selected,
                      onTap: () {
                        ref
                            .read(selectedPaymentMethodIdProvider.notifier)
                            .select(m.id);
                        Navigator.of(context).maybePop();
                      },
                    );
                  },
                );
              },
            ),
          ),
          methodsAsync.maybeWhen(
            data: (methods) {
              if (methods.isEmpty) return const SizedBox.shrink();
              return AppStickyFooter(
                child: AppPrimaryButton(
                  label: 'Add card',
                  onPressed: () => _openAddCard(context),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
