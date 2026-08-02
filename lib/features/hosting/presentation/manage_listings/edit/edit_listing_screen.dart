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
import '../../../../profile/providers/listing_invalidation.dart';
import '../../../../profile/providers/profile_providers.dart';
import 'confirmation_success_screen.dart';
import 'set_availability_chooser_screen.dart';
import 'upload_listing_photo_screen.dart';

// Hero + edit cards for one listing id from Supabase
class EditListingScreen extends ConsumerStatefulWidget {
  const EditListingScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends ConsumerState<EditListingScreen> {
  ListingLocationSharing? _pendingLocationSharing;
  bool _saving = false;
  String? _actionError;
  String? _deleteError;

  ListingLocationSharing _selectedSharing(Listing listing) =>
      _pendingLocationSharing ?? listing.locationSharing;

  bool _isDirty(Listing listing) =>
      _pendingLocationSharing != null &&
      _pendingLocationSharing != listing.locationSharing;

  void _onLocationSharingChanged(Listing listing, ListingLocationSharing next) {
    if (_saving || next == _selectedSharing(listing)) return;
    setState(() {
      _actionError = null;
      _pendingLocationSharing = next == listing.locationSharing ? null : next;
    });
  }

  Future<void> _save(Listing listing) async {
    if (_saving || !_isDirty(listing)) return;
    final next = _pendingLocationSharing!;
    setState(() {
      _saving = true;
      _actionError = null;
    });
    try {
      await ref
          .read(listingsRepositoryProvider)
          .patchListing(listingId: widget.listingId, locationSharing: next);
      invalidateListingSurfaces(ref, widget.listingId);
      if (!mounted) return;
      setState(() {
        _pendingLocationSharing = null;
        _saving = false;
      });
      AppMessenger.showSuccess(
        context,
        next.isGeneral
            ? 'Map shows an approximate area.'
            : 'Map shows a specific pin.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _actionError = 'Could not save changes. Try again.';
      });
    }
  }

  Future<bool> _confirmDiscardIfNeeded(Listing listing) async {
    if (!_isDirty(listing)) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppConfirmDialog(
        title: 'Discard changes?',
        message: 'You have unsaved map sharing changes.',
        cancelLabel: 'Keep editing',
        confirmLabel: 'Discard',
        confirmDestructive: true,
        onCancel: () => Navigator.of(ctx).pop(false),
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (discard == true && mounted) {
      setState(() {
        _pendingLocationSharing = null;
        _actionError = null;
      });
      return true;
    }
    return false;
  }

  Future<void> _onBack(Listing listing) async {
    if (!await _confirmDiscardIfNeeded(listing)) return;
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _confirmDeleteListing() async {
    setState(() => _deleteError = null);
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
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(listingsRepositoryProvider)
          .deleteListing(widget.listingId);
      invalidateListingSurfaces(ref, widget.listingId);
      if (!mounted) return;
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
      if (!mounted) return;
      setState(
        () => _deleteError =
            'Could not delete this listing. Try again or check your connection.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingId = widget.listingId;
    final listingAsync = ref.watch(listingByIdProvider(listingId));
    final photosAsync = ref.watch(listingPhotosProvider(listingId));
    final weeklyAsync = ref.watch(listingAvailabilityWeeklyProvider(listingId));
    final specificAsync = ref.watch(
      listingAvailabilitySpecificProvider(listingId),
    );

    return listingAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const AppTopBar(title: 'Edit listing', showBack: true),
        body: const AppPageStatus.loading(),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: AppColors.surface,
        appBar: const AppTopBar(title: 'Edit listing', showBack: true),
        body: const AppPageStatus.error(),
      ),
      data: (listing) {
        if (listing == null) {
          return Scaffold(
            backgroundColor: AppColors.surface,
            appBar: const AppTopBar(title: 'Edit listing', showBack: true),
            body: const AppPageStatus.empty(title: 'Listing not found'),
          );
        }

        final dirty = _isDirty(listing);
        return PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final nav = Navigator.of(context);
            if (await _confirmDiscardIfNeeded(listing) && mounted) {
              nav.pop();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.surface,
            appBar: AppTopBar(
              title: 'Edit listing',
              showBack: true,
              onBack: _saving ? null : () => _onBack(listing),
            ),
            body: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
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
                                builder: (_) => UploadListingPhotoScreen(
                                  listingId: listingId,
                                ),
                              ),
                            );
                          },
                        ),
                        _EditListingDetails(
                          listingId: listingId,
                          listing: listing,
                          weeklyAsync: weeklyAsync,
                          specificAsync: specificAsync,
                          locationSharing: _selectedSharing(listing),
                          locationSharingEnabled: !_saving,
                          onLocationSharingChanged: (next) =>
                              _onLocationSharingChanged(listing, next),
                          deleteError: _deleteError,
                          onDismissDeleteError: () =>
                              setState(() => _deleteError = null),
                          onDelete: _confirmDeleteListing,
                        ),
                      ],
                    ),
                  ),
                ),
                AppStickyFooter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_actionError != null) ...[
                        AppInlineError(
                          message: _actionError!,
                          onDismiss: () => setState(() => _actionError = null),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AppPrimaryButton(
                        label: 'Save changes',
                        onPressed: dirty && !_saving
                            ? () => _save(listing)
                            : null,
                        loading: _saving,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _EditListingDetails extends StatelessWidget {
  const _EditListingDetails({
    required this.listingId,
    required this.listing,
    required this.weeklyAsync,
    required this.specificAsync,
    required this.locationSharing,
    required this.locationSharingEnabled,
    required this.onLocationSharingChanged,
    required this.deleteError,
    required this.onDismissDeleteError,
    required this.onDelete,
  });

  final String listingId;
  final Listing listing;
  final AsyncValue<List<AvailabilityWeekly>> weeklyAsync;
  final AsyncValue<List<AvailabilitySpecific>> specificAsync;
  final ListingLocationSharing locationSharing;
  final bool locationSharingEnabled;
  final ValueChanged<ListingLocationSharing> onLocationSharingChanged;
  final String? deleteError;
  final VoidCallback onDismissDeleteError;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
    final availabilityLoading =
        weeklyAsync.isLoading || specificAsync.isLoading;

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
          _LocationSharingCard(
            locationSharing: locationSharing,
            enabled: locationSharingEnabled,
            onChanged: onLocationSharingChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          if (availabilityLoading)
            const AppDisplayTitledOutlineCard(
              title: 'Availability and price',
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: AppPageStatus.loading(),
              ),
            )
          else
            AppListingEditAvailabilityCard(
              title: 'Availability and price',
              dateRangeSlots: showSpecific ? dateRangeSlots : const [],
              weeklySlots: showSpecific ? const [] : weeklySlots,
              onEdit: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) =>
                        SetAvailabilityChooserScreen(listingId: listingId),
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.md),
          if (deleteError != null) ...[
            AppInlineError(
              message: deleteError!,
              onDismiss: onDismissDeleteError,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppListingDeleteCard(onDelete: onDelete),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _LocationSharingCard extends StatelessWidget {
  const _LocationSharingCard({
    required this.locationSharing,
    required this.enabled,
    required this.onChanged,
  });

  final ListingLocationSharing locationSharing;
  final bool enabled;
  final ValueChanged<ListingLocationSharing> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: 'Map location sharing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Street address stays private until a reservation is confirmed.',
            style: AppTypography.caption.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSegmentControl<ListingLocationSharing>(
            options: const [
              AppSegmentOption(
                value: ListingLocationSharing.general,
                label: 'General',
                icon: Icons.blur_circular_rounded,
              ),
              AppSegmentOption(
                value: ListingLocationSharing.specific,
                label: 'Specific',
                icon: Icons.location_on_rounded,
              ),
            ],
            selected: locationSharing,
            onChanged: (next) {
              if (enabled) onChanged(next);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            locationSharing.isGeneral
                ? 'Show only an approximate area (~2–3 short blocks).'
                : 'Show a pin on the map. Still hides the street address '
                      'until booking.',
            style: AppTypography.caption.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}
