import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/models/availability_specific.dart';
import '../../../../../core/models/availability_weekly.dart';
import '../../../../../core/models/listing.dart';
import '../../../../../core/models/listing_photo.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../profile/providers/listing_invalidation.dart';
import '../../../../profile/providers/profile_providers.dart';
import 'confirmation_success_screen.dart';
import 'set_availability_dates_screen.dart';
import 'set_availability_weekly_screen.dart';
import 'upload_listing_photo_screen.dart';

// Hero + edit cards for one listing id from Supabase
class EditListingScreen extends ConsumerWidget {
  const EditListingScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(listingByIdProvider(listingId));
    final photosAsync = ref.watch(listingPhotosProvider(listingId));
    final weeklyAsync = ref.watch(listingAvailabilityWeeklyProvider(listingId));
    final specificAsync = ref.watch(
      listingAvailabilitySpecificProvider(listingId),
    );
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: 'Edit Listing', showBack: true),
      body: listingAsync.when(
        data: (listing) {
          if (listing == null) {
            return const AppPageStatus.empty(
              title: 'Listing not found',
            );
          }
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroPhotoSection(
                  listingId: listingId,
                  photosAsync: photosAsync,
                  onEditPhoto: () {
                    Navigator.of(context).push(
                      AppPageRoute<void>(
                        builder: (_) =>
                            UploadListingPhotoScreen(listingId: listingId),
                      ),
                    );
                  },
                ),
                _EditListingDetails(
                  listingId: listingId,
                  listing: listing,
                  weeklyAsync: weeklyAsync,
                  specificAsync: specificAsync,
                ),
              ],
            ),
          );
        },
        loading: () => const AppPageStatus.loading(),
        error: (e, st) => const AppPageStatus.error(),
      ),
    );
  }
}

class _HeroPhotoSection extends StatelessWidget {
  const _HeroPhotoSection({
    required this.listingId,
    required this.photosAsync,
    required this.onEditPhoto,
  });

  final String listingId;
  final AsyncValue<List<ListingPhoto>> photosAsync;
  final VoidCallback onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final firstPhoto = photosAsync.maybeWhen(
      data: (photos) {
        if (photos.isEmpty) return null;
        final sorted = [...photos]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return sorted.first;
      },
      orElse: () => null,
    );
    final firstPhotoUrl = firstPhoto?.photoUrl.trim() ?? '';
    final markerFraction =
        firstPhoto?.markerX != null && firstPhoto?.markerY != null
        ? Offset(firstPhoto!.markerX!, firstPhoto.markerY!)
        : null;

    Widget photoContent;
    if (firstPhotoUrl.isNotEmpty) {
      photoContent = Image.network(
        firstPhotoUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: AppColors.secondaryBlue.withValues(alpha: 0.35),
            child: const Icon(
              Icons.photo_camera_outlined,
              size: 40,
              color: AppColors.primaryBlue,
            ),
          );
        },
      );
    } else {
      photoContent = Container(
        color: AppColors.secondaryBlue.withValues(alpha: 0.35),
        child: const Center(
          child: Icon(
            Icons.photo_camera_outlined,
            size: 40,
            color: AppColors.primaryBlue,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppListingPhotoFrame(
          heroTag: 'listing-photo-$listingId',
          onTap: onEditPhoto,
          overlay: Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: AppScrimIconLabelPill(
              icon: Icons.edit_outlined,
              label: 'Edit photo',
            ),
          ),
          child: AppListingPhotoSpotOverlay(
            markerFraction: markerFraction,
            child: photoContent,
          ),
        ),
      ],
    );
  }
}

class _EditListingDetails extends ConsumerWidget {
  const _EditListingDetails({
    required this.listingId,
    required this.listing,
    required this.weeklyAsync,
    required this.specificAsync,
  });

  final String listingId;
  final Listing listing;
  final AsyncValue<List<AvailabilityWeekly>> weeklyAsync;
  final AsyncValue<List<AvailabilitySpecific>> specificAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateRangeSlots = specificAsync.when(
      data: (list) => list
          .map(
            (s) => DateRangeSlot(
              from: s.fromDisplay,
              to: s.toDisplay,
              priceHour: s.priceHour,
              priceDay: s.priceDay,
            ),
          )
          .toList(),
      loading: () => <DateRangeSlot>[],
      error: (e, st) => <DateRangeSlot>[],
    );
    final weeklySlots = weeklyAsync.when(
      data: (list) => list
          .map(
            (w) => WeeklySlot(
              day: w.dayLabel,
              timeRange: w.timeRangeDisplay,
              priceHour: w.priceHour,
              priceDay: w.priceDay,
            ),
          )
          .toList(),
      loading: () => <WeeklySlot>[],
      error: (e, st) => <WeeklySlot>[],
    );
    final effectiveAvailabilityMode =
        listing.availabilityMode == ListingAvailabilityMode.specific ||
            listing.availabilityMode == ListingAvailabilityMode.weekly
        ? listing.availabilityMode
        : (dateRangeSlots.isNotEmpty
              ? ListingAvailabilityMode.specific
              : ListingAvailabilityMode.weekly);

    final showSpecific =
        effectiveAvailabilityMode == ListingAvailabilityMode.specific;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStreetAddressCard(
            title: 'Parking location',
            streetLine: listing.addressLine,
            localityLine: listing.localityLine.isNotEmpty
                ? listing.localityLine
                : null,
            spotLine: listing.spotLabel,
            usePrimaryColorForSecondaryLines: true,
          ),
          const SizedBox(height: AppSpacing.md),
          AppListingEditAvailabilityCard(
            dateRangeSlots: showSpecific ? dateRangeSlots : const [],
            weeklySlots: showSpecific ? const [] : weeklySlots,
            onEdit: () {
              Navigator.of(context).push(
                AppPageRoute<void>(
                  builder: (_) => showSpecific
                      ? SetAvailabilityDatesScreen(listingId: listingId)
                      : SetAvailabilityWeeklyScreen(listingId: listingId),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppListingDeleteCard(
            onDelete: () => _confirmDeleteListing(context, ref, listingId),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteListing(
  BuildContext context,
  WidgetRef ref,
  String listingId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppConfirmDialog(
      title: 'Delete listing',
      message:
          'This takes your spot off the map and stops new bookings. Trips that '
          'already started stay in place until they finish. Listing photos and '
          'saved availability are removed. This cannot be undone.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      confirmDestructive: true,
      onCancel: () => Navigator.of(ctx).pop(false),
      onConfirm: () => Navigator.of(ctx).pop(true),
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(listingsRepositoryProvider).deleteListing(listingId);
    invalidateListingSurfaces(ref, listingId);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => ConfirmationSuccessScreen(
          message: 'Listing has been deleted',
          onClose: () {},
          popsOnClose: 2,
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      AppMessenger.showError(
        context,
        'Could not delete this listing. Try again or check your connection.',
      );
    }
  }
}
