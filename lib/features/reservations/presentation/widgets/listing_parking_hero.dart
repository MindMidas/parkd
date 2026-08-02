import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/assets/parkd_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/profile_providers.dart';

// Full-width 4:3 parking photo with optional spot marker for trip/booking detail.
class ListingParkingHero extends ConsumerWidget {
  const ListingParkingHero({
    super.key,
    this.listingId,
    required this.fallbackImageUrl,
  });

  final String? listingId;
  final String fallbackImageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = listingId?.trim();
    if (id == null || id.isEmpty) {
      return _ListingParkingHeroContent(
        imageUrl: fallbackImageUrl,
        markerFraction: null,
      );
    }

    final photosAsync = ref.watch(listingPhotosProvider(id));
    return photosAsync.when(
      data: (photos) {
        final sorted = [...photos]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final first = sorted.isNotEmpty ? sorted.first : null;
        final fromPhoto = first?.photoUrl.trim() ?? '';
        final url = fromPhoto.isNotEmpty ? fromPhoto : fallbackImageUrl.trim();
        Offset? marker;
        if (first != null && first.markerX != null && first.markerY != null) {
          marker = Offset(first.markerX!, first.markerY!);
        }
        return _ListingParkingHeroContent(
          imageUrl: url,
          markerFraction: marker,
        );
      },
      loading: () => _ListingParkingHeroContent(
        imageUrl: fallbackImageUrl,
        markerFraction: null,
      ),
      error: (_, _) => _ListingParkingHeroContent(
        imageUrl: fallbackImageUrl,
        markerFraction: null,
      ),
    );
  }
}

class _ListingParkingHeroContent extends StatelessWidget {
  const _ListingParkingHeroContent({
    required this.imageUrl,
    required this.markerFraction,
  });

  final String imageUrl;
  final Offset? markerFraction;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    final Widget photo;
    if (url.isEmpty) {
      photo = Image.asset(
        ParkdAssets.reservationParkingSpotPng,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => ColoredBox(
          color: AppColors.secondaryBlue.withValues(alpha: 0.35),
          child: Center(
            child: Icon(
              Icons.local_parking_rounded,
              size: 56,
              color: AppColors.primaryBlue.withValues(alpha: 0.35),
            ),
          ),
        ),
      );
    } else {
      photo = Image.network(
        url,
        key: ValueKey<String>(url),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ColoredBox(
            color: AppColors.secondaryBlue.withValues(alpha: 0.15),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => ColoredBox(
          color: AppColors.secondaryBlue.withValues(alpha: 0.25),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.iconGrey,
              size: 40,
            ),
          ),
        ),
      );
    }

    final withMarker = markerFraction != null
        ? AppListingPhotoSpotOverlay(
            markerFraction: markerFraction,
            child: photo,
          )
        : photo;

    return AppListingPhotoFrame(
      onTap: url.isNotEmpty
          ? () {
              Navigator.of(context).push<void>(
                AppPageRoute<void>(
                  builder: (_) => AppNetworkImageFullscreenScreen(
                    imageUrl: url,
                    markerFraction: markerFraction,
                  ),
                ),
              );
            }
          : null,
      overlay: url.isNotEmpty
          ? Positioned(
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: AppScrimIconLabelPill(
                icon: Icons.open_in_full_rounded,
                label: 'Expand',
                scrimColor: AppColors.scrimOnImage,
              ),
            )
          : null,
      child: withMarker,
    );
  }
}
