import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../core/stripe/stripe_checkout_remote.dart';
import '../../../core/models/payment_record_status.dart';
import '../../../core/models/reservation_checkout_args.dart';
import '../../../core/models/reservation_status.dart';
import '../../../core/messaging/app_messenger.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/scroll_view_bottom_inset.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_providers.dart';
import '../../profile/providers/payment_method_provider.dart';
import '../providers/map_providers.dart';
import '../../reservations/providers/reservations_providers.dart';
import '../../../core/stripe/stripe_checkout_provider.dart';
import 'payment_success_screen.dart';
import '../../../core/theme/app_colors.dart';

class ReservationCheckoutTermsScreen extends ConsumerStatefulWidget {
  const ReservationCheckoutTermsScreen({
    super.key,
    required this.checkout,
  });

  final ReservationCheckoutArgs checkout;

  @override
  ConsumerState<ReservationCheckoutTermsScreen> createState() =>
      _ReservationCheckoutTermsScreenState();
}

class _ReservationCheckoutTermsScreenState
    extends ConsumerState<ReservationCheckoutTermsScreen> {
  bool _agreed = false;
  bool _paying = false;
  String? _pendingReservationId;

  bool _paymentFinalizedOnServer = false;

  Future<void> _abandonUnpaidReservation() async {
    final id = _pendingReservationId;
    if (id == null) return;
    try {
      final repo = ref.read(reservationsRepositoryProvider);
      await repo.updatePaymentStatusForReservation(
        id,
        PaymentRecordStatus.failed,
      );
      await repo.updateReservationStatus(id, ReservationStatus.cancelled);
    } catch (_) {}
    if (mounted) {
      setState(() => _pendingReservationId = null);
    } else {
      _pendingReservationId = null;
    }
    ref.invalidate(driverActiveReservationsProvider);
    ref.invalidate(mapPublishedListingsProvider);
  }

  Future<void> _onPayAndReserve() async {
    if (!_agreed || _paying) return;

    if (kIsWeb) {
      AppMessenger.showError(
        context,
        'Card payments run on the iOS or Android app.',
      );
      return;
    }

    final pk = Stripe.publishableKey.trim();
    if (pk.isEmpty) {
      AppMessenger.showError(
        context,
        'Add STRIPE_PUBLISHABLE_KEY to your .env and rebuild.',
      );
      return;
    }

    final session = ref.read(currentSessionProvider);
    final userId = session?.user.id;
    if (userId == null) {
      AppMessenger.showError(context, 'Sign in to complete payment.');
      return;
    }

    final args = widget.checkout;
    if (args.subtotal <= 0 || args.total <= 0) {
      AppMessenger.showError(context, 'Invalid reservation total.');
      return;
    }

    setState(() => _paying = true);
    var paymentFinalized = false;
    try {
      final repo = ref.read(reservationsRepositoryProvider);
      final stripeRemote = ref.read(stripeCheckoutRemoteProvider);
      // Prefer args; if Review opened before cards finished loading, resolve again
      final paymentMethodId = args.paymentMethodId ??
          ref.read(effectiveSelectedPaymentMethodIdProvider);

      if (_pendingReservationId == null) {
        final created = await repo.createReservationWithPayment(
          listingId: args.listingId,
          driverId: userId,
          startTime: args.startDateTime,
          endTime: args.endDateTime,
          totalPrice: args.subtotal,
          serviceFee: args.serviceFee,
          paymentMethodId: paymentMethodId,
        );
        _pendingReservationId = created.$1.id;
      }
      final reservationId = _pendingReservationId!;
      final clientSecret = await stripeRemote.createPaymentIntentClientSecret(
        reservationId,
        paymentMethodId: paymentMethodId,
      );

      var intent = await Stripe.instance.retrievePaymentIntent(clientSecret);
      final hasSavedPm =
          paymentMethodId != null && paymentMethodId.trim().isNotEmpty;

      if (hasSavedPm) {
        if (intent.status == PaymentIntentsStatus.RequiresAction) {
          intent = await Stripe.instance.handleNextAction(clientSecret);
        }
        var polls = 0;
        while (intent.status == PaymentIntentsStatus.Processing && polls < 12) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          intent = await Stripe.instance.retrievePaymentIntent(clientSecret);
          polls++;
        }
        if (intent.status != PaymentIntentsStatus.Succeeded) {
          if (intent.status == PaymentIntentsStatus.RequiresConfirmation) {
            await Stripe.instance.initPaymentSheet(
              paymentSheetParameters: SetupPaymentSheetParameters(
                paymentIntentClientSecret: clientSecret,
                merchantDisplayName: 'Parkd',
                style: ThemeMode.system,
              ),
            );
            await Stripe.instance.presentPaymentSheet();
            intent = await Stripe.instance.retrievePaymentIntent(clientSecret);
          } else {
            throw const StripeCheckoutRemoteException('Payment was not completed.');
          }
        }
      } else {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'Parkd',
            style: ThemeMode.system,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        intent = await Stripe.instance.retrievePaymentIntent(clientSecret);
      }

      if (intent.status != PaymentIntentsStatus.Succeeded) {
        throw const StripeCheckoutRemoteException('Payment was not completed.');
      }

      final piId = intent.id;
      if (piId.isEmpty) {
        throw const StripeCheckoutRemoteException('Missing payment intent id');
      }

      await stripeRemote.finalizePayment(paymentIntentId: piId);
      paymentFinalized = true;
      _paymentFinalizedOnServer = true;

      ref.invalidate(driverActiveReservationsProvider);
      ref.invalidate(driverPastReservationsProvider);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PaymentSuccessScreen(
            latitude: args.latitude,
            longitude: args.longitude,
          ),
        ),
      );
    } on StripeException catch (e) {
      if (!paymentFinalized) {
        await _abandonUnpaidReservation();
      }
      if (e.error.code == FailureCode.Canceled) {
        return;
      }
      if (mounted) {
        AppMessenger.showError(
          context,
          e.error.localizedMessage ?? 'Payment failed',
        );
      }
    } catch (e) {
      if (!paymentFinalized) {
        await _abandonUnpaidReservation();
      }
      if (mounted) {
        final msg = e is StripeCheckoutRemoteException
            ? e.message
            : e.toString();
        AppMessenger.showError(context, msg);
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = scrollViewBottomInset(context);

    return PopScope(
      canPop: _pendingReservationId == null || _paymentFinalizedOnServer,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_paymentFinalizedOnServer) {
          if (context.mounted) Navigator.of(context).pop();
          return;
        }
        await _abandonUnpaidReservation();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Confirm and pay',
        showBack: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Please read and agree before completing your reservation',
                      style: AppTypography.hubTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Terms and Conditions',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Please read the following terms carefully before confirming your '
                      'parking reservation on Parkd. By paying and reserving, you agree '
                      'to comply with these terms.',
                      style: AppTypography.caption,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppTermsNumberedSection(
                      number: '1',
                      title: 'Booking and payment',
                      body:
                          'When you confirm, you authorize Parkd to charge your selected '
                          'payment method for the reservation total shown on the previous '
                          'screen, including applicable service fees. The booking is between '
                          'you and the host; Parkd processes payment on the platform.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    const AppTermsNumberedSection(
                      number: '2',
                      title: 'Cancellations and refunds',
                      body:
                          'Cancellation and refund eligibility follow Parkd’s cancellation '
                          'policy, which may depend on how far in advance you cancel. '
                          'Repeated late cancellations or no-shows may affect your account.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    const AppTermsNumberedSection(
                      number: '3',
                      title: 'Use of the parking space',
                      body:
                          'You must arrive and leave within your booked window unless the '
                          'host agrees otherwise. Follow any access instructions, signage, '
                          'and local rules. You are responsible for verifying that the '
                          'space is suitable for your vehicle.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    const AppTermsNumberedSection(
                      number: '4',
                      title: 'Safety and liability',
                      body:
                          'You use parking spaces at your own risk. Parkd does not guarantee '
                          'the condition of third-party properties. Report hazards or '
                          'disputes through the app; we are not liable for theft, damage, or '
                          'accidents at the location.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    const AppTermsNumberedSection(
                      number: '5',
                      title: 'Conduct',
                      body:
                          'Treat hosts and neighbours respectfully. Misuse of a space, '
                          'unauthorized overstays, or fraudulent bookings may result in '
                          'cancellation, fees, or suspension from Parkd.',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppDivider(),
                    const SizedBox(height: AppSpacing.sm),
                    const AppTermsNumberedSection(
                      number: '6',
                      title: 'Privacy and data',
                      body:
                          'By using Parkd, you agree to our Privacy Policy. We use your '
                          'information to operate bookings and improve the service. '
                          'Location data is used for parking reservations.',
                    ),
                    SizedBox(height: AppSpacing.lg + bottomInset),
                  ],
                ),
              ),
            ),
            Material(
              color: AppColors.surface,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md + bottomInset,
                ),
                child: Column(
                  children: [
                    AppTermsAgreementCheckboxRow(
                      value: _agreed,
                      onChanged: _paying
                          ? (_) {}
                          : (v) => setState(() => _agreed = v),
                      label: 'I agree to the Parkd Terms and Conditions',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppPrimaryButton(
                      label: 'Pay & reserve',
                      icon: Icons.bolt_rounded,
                      loading: _paying,
                      onPressed: _agreed && !_paying ? _onPayAndReserve : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
