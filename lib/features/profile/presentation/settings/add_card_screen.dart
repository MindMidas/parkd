import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../../core/stripe/stripe_checkout_remote.dart';
import '../../../../core/models/payment_method_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../core/stripe/stripe_checkout_provider.dart';
import '../../providers/payment_method_provider.dart';
import '../../providers/profile_providers.dart';
import 'card_success_screen.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({super.key, this.editing});

  final PaymentMethodRow? editing;

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  bool _stripeBusy = false;
  late final String _setupIdempotencyKey;

  @override
  void initState() {
    super.initState();
    _setupIdempotencyKey = StripeCheckoutRemote.newIdempotencyKey();
  }

  bool get _useStripeSave => !kIsWeb && Stripe.publishableKey.trim().isNotEmpty;

  Future<void> _saveViaStripe() async {
    if (_stripeBusy) return;
    final uid = ref.read(currentSessionProvider)?.user.id;
    if (uid == null) {
      AppMessenger.showError(context, 'Sign in to manage cards.');
      return;
    }
    if (Stripe.publishableKey.trim().isEmpty) {
      AppMessenger.showError(
        context,
        'Add STRIPE_PUBLISHABLE_KEY with --dart-define and rebuild.',
      );
      return;
    }

    setState(() => _stripeBusy = true);
    try {
      final stripeRemote = ref.read(stripeCheckoutRemoteProvider);
      final clientSecret = await stripeRemote.createSetupIntentClientSecret(
        idempotencyKey: _setupIdempotencyKey,
      );
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: clientSecret,
          merchantDisplayName: 'Parkd',
          style: ThemeMode.system,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      final si = await Stripe.instance.retrieveSetupIntent(clientSecret);
      if (si.status.toLowerCase() != 'succeeded') {
        if (!mounted) return;
        AppMessenger.showError(context, 'Card setup did not complete.');
        return;
      }
      final newId = await stripeRemote.completePaymentMethodSetup(
        setupIntentId: si.id,
      );
      ref.invalidate(paymentMethodsForCurrentUserProvider);
      if (newId != null) {
        ref.read(selectedPaymentMethodIdProvider.notifier).select(newId);
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (_) => const CardSuccessScreen(message: 'Card added'),
        ),
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return;
      }
      if (mounted) {
        AppMessenger.showError(
          context,
          e.error.localizedMessage ?? 'Could not save card',
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
      _stripeBusy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _confirmRemove() async {
    final editing = widget.editing;
    if (editing == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: 'Remove card?',
        message: 'This card will be removed from your account.',
        confirmLabel: 'Remove',
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (ok != true || !mounted) return;
    final uid = ref.read(currentSessionProvider)?.user.id;
    if (uid == null) return;
    try {
      await ref
          .read(paymentMethodsRepositoryProvider)
          .remove(userId: uid, id: editing.id);
      ref.invalidate(paymentMethodsForCurrentUserProvider);
    } catch (_) {
      if (!mounted) return;
      AppMessenger.showError(context, 'Could not remove card.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final bottom = scrollViewBottomInset(context);
    final cardCount = ref
        .watch(paymentMethodsForCurrentUserProvider)
        .maybeWhen(data: (l) => l.length, orElse: () => 0);

    final stripeLinkedEdit =
        editing != null &&
        editing.stripePaymentMethodId != null &&
        editing.stripePaymentMethodId!.trim().isNotEmpty;

    if (stripeLinkedEdit) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(title: 'Saved card', showBack: true),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl + bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${editing.brand ?? 'Card'} •••• ${editing.last4 ?? '••••'}',
                      style: AppTypography.bodyStrong,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'This card is stored with Stripe and used when you pay '
                      'for reservations. To use a different card, remove this '
                      'one and add a new card from Payment methods.',
                      style: AppTypography.caption,
                    ),
                    if (cardCount > 1) ...[
                      const SizedBox(height: AppSpacing.xl),
                      AppListingDeleteCard(
                        title: 'Remove card',
                        onDelete: _confirmRemove,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (cardCount <= 1)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg + bottom,
                ),
                child: AppListingDeleteCard(
                  title: 'Remove card',
                  onDelete: _confirmRemove,
                ),
              ),
          ],
        ),
      );
    }

    if (_useStripeSave && editing == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const AppTopBar(title: 'Add New Card', showBack: true),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.only(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.xl + bottom,
                ),
                child: AppScreenSection(
                  horizontalPadding: AppSpacing.lg,
                  title: 'Secure card setup',
                  description:
                      'You’ll enter your card in Stripe’s secure payment sheet.',
                  child: const AppFormHelperText(
                    'We only store brand, last four digits, and a Stripe '
                    'token in Parkd — never your full card number.',
                  ),
                ),
              ),
            ),
            AppSurfaceFooterPad(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md + bottom,
              ),
              child: AppPrimaryButton(
                label: 'Add card',
                icon: Icons.credit_card_rounded,
                loading: _stripeBusy,
                onPressed: _stripeBusy ? null : _saveViaStripe,
              ),
            ),
          ],
        ),
      );
    }

    final isLegacyDisplayOnlyCard = editing != null && !stripeLinkedEdit;
    if (isLegacyDisplayOnlyCard || editing == null) {
      final title = editing == null ? 'Add New Card' : 'Saved card';
      final message = editing == null
          ? 'Card setup is only available in the iOS or Android app after '
                'STRIPE_PUBLISHABLE_KEY is configured. Parkd does not store '
                'manual card numbers or display-only card records.'
          : 'This saved card was created without a Stripe payment token. '
                'For security, it can be removed but not edited or used at '
                'checkout. Add a new card on mobile after Stripe is configured.';

      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(title: title, showBack: true),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl + bottom,
                ),
                child: AppScreenSection(
                  horizontalPadding: 0,
                  title: editing == null
                      ? 'Secure card setup unavailable'
                      : '${editing.brand ?? 'Card'} •••• ${editing.last4 ?? '••••'}',
                  description: message,
                  child: editing == null
                      ? const AppFormHelperText(
                          'Set STRIPE_PUBLISHABLE_KEY with --dart-define, then '
                          'run on iOS or Android.',
                        )
                      : const AppFormHelperText(
                          'Legacy display-only cards should be removed and '
                          'replaced with Stripe-backed saved cards.',
                        ),
                ),
              ),
            ),
            if (editing != null)
              AppSurfaceFooterPad(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.md + bottom,
                ),
                child: AppPrimaryButton(
                  label: 'Remove card',
                  icon: Icons.delete_outline_rounded,
                  destructive: true,
                  onPressed: _confirmRemove,
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: const SizedBox.shrink(),
    );
  }
}
