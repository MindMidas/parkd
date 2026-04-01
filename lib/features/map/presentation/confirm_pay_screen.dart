import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/models/reservation_checkout_args.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/scroll_view_bottom_inset.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/presentation/settings/all_cards_screen.dart';
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
      appBar: const AppTopBar(
        title: 'Review & Confirm',
        showBack: true,
      ),
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
                    AppStreetAddressCard(
                      title: 'Parking location',
                      streetLine: streetAddress,
                      localityLine: localityLine.isNotEmpty
                          ? localityLine
                          : null,
                      spotLine: spotLabel,
                      usePrimaryColorForSecondaryLines: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppDisplayTitledOutlineCard(
                      title: 'Reservation duration',
                      child: AppDetailDurationTimingBlock.fromDateTimes(
                        start: startDateTime,
                        end: endDateTime,
                        totalTimeLabel: durationLabel,
                        animate: false,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCheckoutPriceBreakdownCard(
                      subtotal: subtotal,
                      serviceFee: serviceFee,
                      total: total,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Consumer(
                      builder: (context, ref, _) {
                        final method = ref.watch(selectedPaymentMethodProvider);
                        return AppCheckoutPaymentMethodField(
                          brand: method?.brand ?? 'Add a card',
                          lastFour: method?.last4 ?? '—',
                          onChangePressed: () {
                            Navigator.of(context, rootNavigator: true).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const AllCardsScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    SizedBox(height: AppSpacing.lg + bottomInset),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg + bottomInset,
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final methodsAsync =
                      ref.watch(paymentMethodsForCurrentUserProvider);
                  final effectivePmId =
                      ref.watch(effectiveSelectedPaymentMethodIdProvider);
                  final method = ref.watch(selectedPaymentMethodProvider);
                  final stripePk = Stripe.publishableKey.trim();
                  final needsStripePm =
                      !kIsWeb && stripePk.isNotEmpty;
                  final stripeLinked =
                      (method?.stripePaymentMethodId ?? '').trim().isNotEmpty;
                  final methodsReady = methodsAsync.hasValue;
                  final canProceed = !needsStripePm ||
                      (methodsReady &&
                          effectivePmId != null &&
                          stripeLinked);

                  return AppPrimaryButton(
                    label: 'Looks good',
                    icon: Icons.thumb_up_rounded,
                    onPressed: canProceed
                        ? () {
                            final paymentMethodId = ref.read(
                              effectiveSelectedPaymentMethodIdProvider,
                            );
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
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
