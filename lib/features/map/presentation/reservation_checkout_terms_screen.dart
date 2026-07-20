import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/stripe/stripe_checkout_remote.dart';
import '../../../core/models/reservation_checkout_args.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/providers/payment_method_provider.dart';
import '../providers/map_providers.dart';
import '../../reservations/providers/reservations_providers.dart';
import '../../../core/stripe/stripe_checkout_provider.dart';
import 'payment_success_screen.dart';
import '../../../core/theme/app_colors.dart';

class ReservationCheckoutTermsScreen extends ConsumerStatefulWidget {
  const ReservationCheckoutTermsScreen({super.key, required this.checkout});

  final ReservationCheckoutArgs checkout;

  @override
  ConsumerState<ReservationCheckoutTermsScreen> createState() =>
      _ReservationCheckoutTermsScreenState();
}

class _ReservationCheckoutTermsScreenState
    extends ConsumerState<ReservationCheckoutTermsScreen> {
  bool _agreed = false;
  bool _paying = false;
  bool _preparingCheckout = true;
  String? _pendingReservationId;
  String? _checkoutError;
  TrustedCheckoutSession? _trustedCheckout;
  late final String _idempotencyKey;

  bool _paymentFinalizedOnServer = false;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = StripeCheckoutRemote.newIdempotencyKey();
    Future<void>.microtask(_prepareTrustedCheckout);
  }

  Uri _webReturnUrl(String result) {
    return Uri.base.replace(
      path: '/home',
      queryParameters: {'tab': 'reservations', 'checkout': result},
      fragment: null,
    );
  }

  Future<void> _prepareTrustedCheckout() async {
    if (_preparingCheckout && _trustedCheckout != null) return;
    if (mounted) {
      setState(() {
        _preparingCheckout = true;
        _checkoutError = null;
      });
    }
    try {
      final args = widget.checkout;
      final selectedPaymentMethodId = kIsWeb
          ? null
          : args.paymentMethodId ??
                ref.read(effectiveSelectedPaymentMethodIdProvider);
      final checkout = await ref
          .read(stripeCheckoutRemoteProvider)
          .createCheckout(
            listingId: args.listingId,
            startTime: args.startDateTime,
            endTime: args.endDateTime,
            paymentMethodId: selectedPaymentMethodId,
            idempotencyKey: _idempotencyKey,
            web: kIsWeb,
            successUrl: kIsWeb ? _webReturnUrl('success') : null,
            cancelUrl: kIsWeb ? _webReturnUrl('cancelled') : null,
          );
      if (!mounted) return;
      setState(() {
        _trustedCheckout = checkout;
        _pendingReservationId = checkout.reservationId;
        _preparingCheckout = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _preparingCheckout = false;
        _checkoutError = error is StripeCheckoutRemoteException
            ? error.message
            : 'Secure checkout is temporarily unavailable. Try again.';
      });
    }
  }

  Future<void> _abandonUnpaidReservation() async {
    final id = _pendingReservationId;
    if (id == null) return;
    try {
      final repo = ref.read(reservationsRepositoryProvider);
      await repo.cancelCheckoutHold(id);
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

    if (!kIsWeb && Stripe.publishableKey.trim().isEmpty) {
      AppMessenger.showError(
        context,
        'Add STRIPE_PUBLISHABLE_KEY with --dart-define and rebuild.',
      );
      return;
    }

    final args = widget.checkout;
    final checkout = _trustedCheckout;
    if (checkout == null) {
      AppMessenger.showError(context, 'Secure checkout is not ready yet.');
      return;
    }

    setState(() => _paying = true);
    try {
      final stripeRemote = ref.read(stripeCheckoutRemoteProvider);
      if (kIsWeb) {
        final url = checkout.checkoutUrl;
        if (url == null) {
          throw const StripeCheckoutRemoteException(
            'Secure web checkout URL is missing.',
          );
        }
        final opened = await launchUrl(url, webOnlyWindowName: '_self');
        if (!opened) {
          throw const StripeCheckoutRemoteException(
            'Could not open secure web checkout.',
          );
        }
        return;
      }

      final clientSecret = checkout.clientSecret;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw const StripeCheckoutRemoteException(
          'Secure mobile checkout is missing its payment token.',
        );
      }
      final paymentMethodId =
          args.paymentMethodId ??
          ref.read(effectiveSelectedPaymentMethodIdProvider);

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
            throw const StripeCheckoutRemoteException(
              'Payment was not completed.',
            );
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
      _paymentFinalizedOnServer = true;

      ref.invalidate(driverActiveReservationsProvider);
      ref.invalidate(driverPastReservationsProvider);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PaymentSuccessScreen()),
      );
    } on StripeException catch (e) {
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

  Widget _securePriceSummary() {
    final checkout = _trustedCheckout;
    if (_preparingCheckout) {
      return const AppDisplayTitledOutlineCard(
        title: 'Server-verified total',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_checkoutError != null) {
      return AppDisplayTitledOutlineCard(
        title: 'Secure checkout unavailable',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_checkoutError!, style: AppTypography.bodyMuted),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Retry secure checkout',
              icon: Icons.refresh_rounded,
              onPressed: _prepareTrustedCheckout,
            ),
          ],
        ),
      );
    }
    if (checkout == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCheckoutPriceBreakdownCard(
          subtotal: checkout.subtotal,
          serviceFee: checkout.serviceFee,
          total: checkout.total,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${checkout.currency} · Recalculated securely from the listing availability. '
          'Only Stripe test payments are accepted.',
          style: AppTypography.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
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
        appBar: const AppTopBar(title: 'Confirm and pay', showBack: true),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.lg),
                      _securePriceSummary(),
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
                            'payment method for the server-verified reservation total shown '
                            'above, including applicable service fees. The booking is between '
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
                            'Location data is used to facilitate parking reservations.',
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
                        onChanged: _paying || _trustedCheckout == null
                            ? (_) {}
                            : (v) => setState(() => _agreed = v),
                        label: 'I agree to the Parkd Terms and Conditions',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppPrimaryButton(
                        label: kIsWeb
                            ? 'Continue to Stripe test checkout'
                            : 'Pay & reserve',
                        icon: Icons.bolt_rounded,
                        loading: _paying || _preparingCheckout,
                        onPressed:
                            _agreed &&
                                !_paying &&
                                !_preparingCheckout &&
                                _trustedCheckout != null
                            ? _onPayAndReserve
                            : null,
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
