import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/listing.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../providers/profile_providers.dart';
import 'confirmation_success_screen.dart';
import '../../create_listing/create_listing_flow/terms_and_conditions_screen.dart';

/// Edit listing price: hourly and daily steppers, then confirm -> success.
/// Initial values come from [listingId] via [listingByIdProvider] when available.
class ModifyPriceScreen extends ConsumerStatefulWidget {
  const ModifyPriceScreen({
    super.key,
    required this.listingId,
    this.slots = const [],
    this.currentStep,
    this.totalSteps,
  });

  final String listingId;
  final int? currentStep;
  final int? totalSteps;
  final List<String> slots;

  @override
  ConsumerState<ModifyPriceScreen> createState() => _ModifyPriceScreenState();
}

class _ModifyPriceScreenState extends ConsumerState<ModifyPriceScreen> {
  int _hourly = 10;
  int _daily = 30;
  String? _initializedForListingId;

  void _applyListingPrice(Listing? listing) {
    if (listing == null || _initializedForListingId == widget.listingId) return;
    _initializedForListingId = widget.listingId;
    setState(() {
      _hourly = listing.priceHour.round().clamp(0, 999);
      _daily = (listing.priceDay ?? 30).round().clamp(0, 9999);
    });
  }

  void _onConfirm() {
    if (widget.currentStep != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TermsAndConditionsScreen(
            onPublish: () {
              // handle publish
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConfirmationSuccessScreen(
                    message: 'Listing Publish',
                    onClose: () {},
                    popsOnClose: 9,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConfirmationSuccessScreen(
            message: 'Price updated',
            onClose: () {},
            popsOnClose: 2,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(listingByIdProvider(widget.listingId));
    if (listingAsync.hasValue &&
        listingAsync.value != null &&
        _initializedForListingId != widget.listingId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyListingPrice(listingAsync.value);
      });
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(title: 'Modify Price', showBack: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Choose how much drivers pay',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPriceStepper(
                label: 'Hourly price',
                value: _hourly,
                min: 0,
                max: 999,
                onChanged: (v) => setState(() => _hourly = v.toInt()),
              ),
              AppPriceStepper(
                label: 'Daily price (optional)',
                value: _daily,
                min: 0,
                max: 9999,
                onChanged: (v) => setState(() => _daily = v.toInt()),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppInfoText(
                'Changes will only apply to future reservations.\n'
                'Existing or ongoing bookings will not be affected.',
                textAlign: TextAlign.center,
              ),
              const AppSectionDividerTitle('Scheduled time slots'),
              ...widget.slots.map((slot) {
                final parts = slot.split('  ');
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.iconGrey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    child: AppSlotCardRemoveWeekly(
                      day: parts.first,
                      timeRange: parts.length > 1 ? parts.last : '',
                    ),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.md),
              AppSecondaryButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                onPressed: () =>
                    Navigator.of(context).pop(), // goes back to weekly screen
              ),
              const Spacer(),
              AppPrimaryButton(label: 'Confirm', onPressed: _onConfirm),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
