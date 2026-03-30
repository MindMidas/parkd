import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../../../core/stripe/stripe_checkout_remote.dart';
import '../../../../core/models/payment_method_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/messaging/app_messenger.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/scroll_view_bottom_inset.dart';
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
  final _formKey = GlobalKey<FormState>();
  late String _brand;
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalController = TextEditingController();

  late final String _initialBrand;
  late final String _initialName;
  late final String _initialExpiry;
  late final String _initialCvv;
  late final String _initialStreet;
  late final String _initialCity;
  late final String _initialPostal;

  bool _stripeBusy = false;

  bool get _useStripeSave =>
      !kIsWeb && Stripe.publishableKey.trim().isNotEmpty;

  void _onFieldChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _brand = (e?.brand != null && e!.brand!.isNotEmpty) ? e.brand! : 'Visa';
    if (e != null) {
      _numberController.text = '';
    }

    _initialBrand = _brand;
    _initialName = _nameController.text;
    _initialExpiry = _expiryController.text;
    _initialCvv = _cvvController.text;
    _initialStreet = _streetController.text;
    _initialCity = _cityController.text;
    _initialPostal = _postalController.text;

    _numberController.addListener(_onFieldChanged);
    _nameController.addListener(_onFieldChanged);
    _expiryController.addListener(_onFieldChanged);
    _cvvController.addListener(_onFieldChanged);
    _streetController.addListener(_onFieldChanged);
    _cityController.addListener(_onFieldChanged);
    _postalController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _numberController.removeListener(_onFieldChanged);
    _nameController.removeListener(_onFieldChanged);
    _expiryController.removeListener(_onFieldChanged);
    _cvvController.removeListener(_onFieldChanged);
    _streetController.removeListener(_onFieldChanged);
    _cityController.removeListener(_onFieldChanged);
    _postalController.removeListener(_onFieldChanged);
    _numberController.dispose();
    _nameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  bool _hasChangesFromInitial() {
    if (_brand != _initialBrand) return true;
    final numDigits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    if (numDigits.isNotEmpty) return true;
    if (_nameController.text != _initialName) return true;
    if (_expiryController.text != _initialExpiry) return true;
    if (_cvvController.text != _initialCvv) return true;
    if (_streetController.text != _initialStreet) return true;
    if (_cityController.text != _initialCity) return true;
    if (_postalController.text != _initialPostal) return true;
    return false;
  }

  String? _digitsLast4(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length < 4) return null;
    return d.substring(d.length - 4);
  }

  (int?, int?) _parseExpiry(String raw) {
    final p = raw.trim().split(RegExp(r'[/\-]'));
    if (p.length != 2) return (null, null);
    final m = int.tryParse(p[0]);
    var y = int.tryParse(p[1]);
    if (m == null || y == null) return (null, null);
    if (y < 100) y += 2000;
    return (m, y);
  }

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
        'Add STRIPE_PUBLISHABLE_KEY to your .env and rebuild.',
      );
      return;
    }

    setState(() => _stripeBusy = true);
    try {
      final stripeRemote = ref.read(stripeCheckoutRemoteProvider);
      final clientSecret = await stripeRemote.createSetupIntentClientSecret();
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
        MaterialPageRoute<void>(
          builder: (_) => const CardSuccessScreen(
            message: 'Card added',
          ),
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

  Future<void> _submitManual() async {
    if (!_formKey.currentState!.validate()) return;
    var last4 = _digitsLast4(_numberController.text);
    if (last4 == null && widget.editing != null) {
      last4 = widget.editing!.last4;
    }
    if (last4 == null) {
      AppMessenger.showError(context, 'Enter a valid card number.');
      return;
    }

    final uid = ref.read(currentSessionProvider)?.user.id;
    if (uid == null) {
      AppMessenger.showError(context, 'Sign in to manage cards.');
      return;
    }
    final repo = ref.read(paymentMethodsRepositoryProvider);
    final (expM, expY) = _parseExpiry(_expiryController.text);

    try {
      if (widget.editing != null) {
        await repo.updateDisplayFields(
          userId: uid,
          id: widget.editing!.id,
          brand: _brand,
          last4: last4,
          expMonth: expM,
          expYear: expY,
        );
      } else {
        final existing =
            await ref.read(paymentMethodsForCurrentUserProvider.future);
        final added = await repo.addMethod(
          userId: uid,
          brand: _brand,
          last4: last4,
          expMonth: expM,
          expYear: expY,
          setAsDefault: existing.isEmpty,
        );
        ref.read(selectedPaymentMethodIdProvider.notifier).select(added.id);
      }
      ref.invalidate(paymentMethodsForCurrentUserProvider);
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showError(context, 'Could not save card.');
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardSuccessScreen(
          message: widget.editing != null ? 'Card updated' : 'Card added',
        ),
      ),
    );
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
    final cardCount = ref.watch(paymentMethodsForCurrentUserProvider).maybeWhen(
          data: (l) => l.length,
          orElse: () => 0,
        );

    final stripeLinkedEdit = editing != null &&
        editing.stripePaymentMethodId != null &&
        editing.stripePaymentMethodId!.trim().isNotEmpty;

    if (stripeLinkedEdit) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(
          title: 'Saved card',
          showBack: true,
        ),
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
        appBar: const AppTopBar(
          title: 'Add New Card',
          showBack: true,
        ),
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: editing != null ? 'Edit card' : 'Add New Card',
        showBack: true,
      ),
      body: Column(
        children: [
          if (!_useStripeSave && editing == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                'On the web, cards are saved for display only. '
                'Use the iOS or Android app with Stripe configured to save a card for checkout.',
                style: AppTypography.caption,
              ),
            ),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (editing != null &&
                        (editing.stripePaymentMethodId == null ||
                            editing.stripePaymentMethodId!.trim().isEmpty)) ...[
                      Text(
                        'This card was added without Stripe. Remove it and '
                        'use Add card on mobile to save a card for checkout.',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    AppPaymentCardDetailsFieldsCard(
                      selectedBrand: _brand,
                      onBrandChanged: (b) {
                        setState(() => _brand = b);
                      },
                      numberController: _numberController,
                      nameController: _nameController,
                      expiryController: _expiryController,
                      cvvController: _cvvController,
                      editingLastFour: editing?.last4,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppBillingAddressFieldsCard(
                      streetController: _streetController,
                      cityController: _cityController,
                      postalController: _postalController,
                    ),
                    if (editing != null && cardCount > 1) ...[
                      const SizedBox(height: AppSpacing.xl),
                      AppListingDeleteCard(
                        title: 'Delete card',
                        onDelete: _confirmRemove,
                      ),
                    ],
                    SizedBox(height: AppSpacing.lg + bottom),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg + bottom,
            ),
            child: AppPrimaryButton(
              label: 'Confirm',
              icon: Icons.check_rounded,
              onPressed: _hasChangesFromInitial() ? _submitManual : null,
            ),
          ),
        ],
      ),
    );
  }
}
