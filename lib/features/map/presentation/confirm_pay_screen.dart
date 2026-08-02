import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/models/reservation_checkout_args.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/presentation/settings/select_payment_method_screen.dart';
import '../../profile/providers/payment_method_provider.dart';
import '../../profile/providers/profile_providers.dart';
import 'reservation_checkout_terms_screen.dart';
import '../../../core/theme/app_colors.dart';

class ConfirmPayScreen extends ConsumerWidget {
  const ConfirmPayScreen({
    super.key,
    required this.listingId,
    required this.streetAddress,
    required this.localityLine,
    this.spotLabel,
    required this.startDateTime,
    required this.endDateTime,
    required this.durationLabel,
    required this.subtotal,
    required this.serviceFee,
    required this.latitude,
    required this.longitude,
  });

  final String listingId;
  final String streetAddress;
  final String localityLine;
  final String? spotLabel;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String durationLabel;
  final double subtotal;
  final double serviceFee;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = subtotal + serviceFee;
    final bottomInset = scrollViewBottomInset(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Review', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text('Location', style: AppTypography.overline),
                    const SizedBox(height: AppSpacing.sm),
                    AppStreetAddressCard(
                      streetLine: streetAddress,
                      localityLine: localityLine.isNotEmpty
                          ? localityLine
                          : null,
                      spotLine: spotLabel,
                      usePrimaryColorForSecondaryLines: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Duration', style: AppTypography.overline),
                    const SizedBox(height: AppSpacing.sm),
                    AppDisplayOutlineCard(
                      child: AppDetailDurationTimingBlock.fromDateTimes(
                        start: startDateTime,
                        end: endDateTime,
                        totalTimeLabel: durationLabel,
                        animate: false,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppCheckoutPriceBreakdownCard(
                      subtotal: subtotal,
                      serviceFee: serviceFee,
                      total: total,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (kIsWeb)
                      AppDisplayTitledOutlineCard(
                        title: 'Payment method',
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lock_outline_rounded),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                Stripe.publishableKey.trim().startsWith(
                                      'pk_test_',
                                    )
                                    ? 'Enter a Stripe test card on the secure '
                                          'hosted checkout page. Parkd never '
                                          'receives or stores the card number.'
                                    : 'You’ll enter your card on Stripe’s '
                                          'secure hosted checkout page. Parkd '
                                          'never receives or stores the card '
                                          'number.',
                                style: AppTypography.bodyMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Consumer(
                        builder: (context, ref, _) {
                          final method = ref.watch(
                            selectedPaymentMethodProvider,
                          );
                          final stripePk = Stripe.publishableKey.trim();
                          final warnLegacy =
                              stripePk.isNotEmpty &&
                              method != null &&
                              (method.stripePaymentMethodId == null ||
                                  method.stripePaymentMethodId!.trim().isEmpty);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppCheckoutPaymentMethodField(
                                brand: method == null
                                    ? 'Add a card'
                                    : (method.brand ?? 'Card'),
                                lastFour: method?.last4,
                                onChangePressed: () {
                                  Navigator.of(context).push<void>(
                                    AppPageRoute<void>(
                                      builder: (_) =>
                                          const SelectPaymentMethodScreen(),
                                    ),
                                  );
                                },
                              ),
                              if (warnLegacy) ...[
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'This saved card is not linked to Stripe. '
                                  'Remove it in Account → Payment methods and add '
                                  'a card again so checkout can charge it.',
                                  style: AppTypography.caption,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    SizedBox(height: AppSpacing.lg + bottomInset),
                  ],
                ),
              ),
            ),
            AppStickyFooter(
              child: Consumer(
                builder: (context, ref, _) {
                  final methodsAsync = ref.watch(
                    paymentMethodsForCurrentUserProvider,
                  );
                  final effectivePmId = ref.watch(
                    effectiveSelectedPaymentMethodIdProvider,
                  );
                  final method = ref.watch(selectedPaymentMethodProvider);
                  final stripePk = Stripe.publishableKey.trim();
                  final needsStripePm = !kIsWeb && stripePk.isNotEmpty;
                  final stripeLinked = (method?.stripePaymentMethodId ?? '')
                      .trim()
                      .isNotEmpty;
                  final methodsReady = methodsAsync.hasValue;
                  final canProceed =
                      !needsStripePm ||
                      (methodsReady && effectivePmId != null && stripeLinked);

                  return AppPrimaryButton(
                    label: 'Continue',
                    onPressed: canProceed
                        ? () {
                            final paymentMethodId = ref.read(
                              effectiveSelectedPaymentMethodIdProvider,
                            );
                            Navigator.of(context).push<void>(
                              AppPageRoute<void>(
                                builder: (_) => ReservationCheckoutTermsScreen(
                                  checkout: ReservationCheckoutArgs(
                                    listingId: listingId,
                                    startDateTime: startDateTime,
                                    endDateTime: endDateTime,
                                    subtotal: subtotal,
                                    serviceFee: serviceFee,
                                    latitude: latitude,
                                    longitude: longitude,
                                    paymentMethodId: paymentMethodId,
                                  ),
                                ),
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
