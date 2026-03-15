import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/availability_specific.dart';
import '../../../../../core/models/availability_weekly.dart';
import '../../../../../core/models/listing.dart';
import '../../../../../core/models/listing_photo.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../home/presentation/home_map_screen.dart';
import '../../../providers/profile_providers.dart';
import 'confirmation_success_screen.dart';
import 'modify_price_screen.dart';
import 'set_availability_chooser_screen.dart';
import 'upload_listing_photo_screen.dart';

class EditListingScreen extends ConsumerWidget {
  const EditListingScreen({
    super.key,
    required this.listingId,
  });

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingByIdProvider(listingId));
    final photosAsync = ref.watch(listingPhotosProvider(listingId));
    final weeklyAsync = ref.watch(listingAvailabilityWeeklyProvider(listingId));
    final specificAsync = ref.watch(listingAvailabilitySpecificProvider(listingId));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppTopBar(
        title: 'Edit Listing',
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: listingAsync.when(
        data: (listing) {
          if (listing == null) {
            return Center(
              child: Text(
                'Listing not found',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
            );
          }
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroPhotoSection(listing: listing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: _EditListingDetails(
                    listingId: listingId,
                    listing: listing,
                    photosAsync: photosAsync,
                    weeklyAsync: weeklyAsync,
                    specificAsync: specificAsync,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'Something went wrong',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeMapScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
    );
  }
}

class _HeroPhotoSection extends StatelessWidget {
  const _HeroPhotoSection({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: AppColors.secondaryBlue.withValues(alpha: 0.35),
            child: const Center(
              child: Icon(
                Icons.photo_camera_outlined,
                size: 40,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                listing.addressLine,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                listing.subtitle,
                style: AppTypography.caption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditListingDetails extends StatelessWidget {
  const _EditListingDetails({
    required this.listingId,
    required this.listing,
    required this.photosAsync,
    required this.weeklyAsync,
    required this.specificAsync,
  });

  final String listingId;
  final Listing listing;
  final AsyncValue<List<ListingPhoto>> photosAsync;
  final AsyncValue<List<AvailabilityWeekly>> weeklyAsync;
  final AsyncValue<List<AvailabilitySpecific>> specificAsync;

  @override
  Widget build(BuildContext context) {
    final photoLabel = photosAsync.when(
      data: (photos) => photos.isEmpty
          ? 'Add photo'
          : photos.length == 1
              ? '1 photo'
              : '${photos.length} photos',
      loading: () => '…',
      error: (e, st) => 'Photo',
    );
    final dateRangeSlots = specificAsync.when(
      data: (list) => list
          .map((s) => DateRangeSlot(from: s.fromDisplay, to: s.toDisplay))
          .toList(),
      loading: () => <DateRangeSlot>[],
      error: (e, st) => <DateRangeSlot>[],
    );
    final weeklySlots = weeklyAsync.when(
      data: (list) => list
          .map((w) => WeeklySlot(day: w.dayLabel, timeRange: w.timeRangeDisplay))
          .toList(),
      loading: () => <WeeklySlot>[],
      error: (e, st) => <WeeklySlot>[],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppEditableRow(
          label: 'Photo',
          value: photoLabel,
          onEdit: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => UploadListingPhotoScreen(listingId: listingId),
              ),
            );
          },
        ),
        const AppDivider(),
        AppEditableRow(
          label: 'Price',
          value: listing.priceSummary,
          onEdit: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ModifyPriceScreen(listingId: listingId),
              ),
            );
          },
        ),
        const AppDivider(),
        AppAvailabilitySlots.combined(
          title: 'AVAILABILITY',
          dateRangeSlots:
              dateRangeSlots.isEmpty ? null : dateRangeSlots,
          weeklySlots: weeklySlots.isEmpty ? null : weeklySlots,
          onEdit: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SetAvailabilityChooserScreen(listingId: listingId),
              ),
            );
          },
          editButtonFullWidth: true,
        ),
        const AppDivider(),
        _DeleteSection(
          onPressed: () => _showDeleteListingDialog(context),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

void _showDeleteListingDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AppConfirmDialog(
      title: 'Delete Listing',
      message:
          'This action will permanently remove your parking listing. '
          'Drivers will no longer be able to book this spot. '
          'Existing reservations will remain active.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      onCancel: () => Navigator.of(ctx).pop(),
      onConfirm: () {
        Navigator.of(ctx).pop();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConfirmationSuccessScreen(
              message: 'Listing has been deleted',
              onClose: () {},
              popsOnClose: 2,
            ),
          ),
        );
      },
    ),
  );
}

class _DeleteSection extends StatelessWidget {
  const _DeleteSection({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DELETE LISTING',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This action is irreversible',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Delete',
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

