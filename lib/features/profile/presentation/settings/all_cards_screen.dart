import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/payment_method_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/payment_method_provider.dart';
import '../../providers/profile_providers.dart';
import 'add_card_screen.dart';
import 'select_payment_method_screen.dart';

// All saved cards, default picker, FAB-style add
class AllCardsScreen extends ConsumerWidget {
  const AllCardsScreen({super.key});

  static String _brand(PaymentMethodRow m) => m.brand ?? 'Card';
  static String _last4(PaymentMethodRow m) => m.last4 ?? '••••';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = scrollViewBottomInset(context);
    final methodsAsync = ref.watch(paymentMethodsForCurrentUserProvider);
    final method = ref.watch(selectedPaymentMethodProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'All Cards', showBack: true),
      body: methodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('Could not load cards.')),
        data: (cards) {
          final defaultRow = method ?? (cards.isNotEmpty ? cards.first : null);
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl + 52 + AppSpacing.md + bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (defaultRow != null)
                  AppCheckoutPaymentMethodField(
                    title: 'Default payment method',
                    brand: _brand(defaultRow),
                    lastFour: _last4(defaultRow),
                    onChangePressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const SelectPaymentMethodScreen(),
                        ),
                      );
                    },
                  )
                else
                  const AppFormHelperText('Add a card to use at checkout.'),
                const SizedBox(height: AppSpacing.lg),
                AppDisplayTitledOutlineCard(
                  title: 'Your cards',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (cards.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Text('No cards yet.'),
                        )
                      else
                        for (var i = 0; i < cards.length; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.sm),
                          AppSavedPaymentCardRow(
                            brand: _brand(cards[i]),
                            lastFour: _last4(cards[i]),
                            onTap: () {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      AddCardScreen(editing: cards[i]),
                                ),
                              );
                            },
                          ),
                        ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const AppFormHelperText(
                  'Tap a card to edit details or remove it. Choose your default card above.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Material(
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: AppPrimaryButton(
              label: 'Add card',
              icon: Icons.add_rounded,
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AddCardScreen(),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
