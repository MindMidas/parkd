import 'package:flutter/material.dart';

import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';

// Responsive discovery experience used where Mapbox has no native SDK.
class MapPlatformFallback extends StatelessWidget {
  const MapPlatformFallback({
    super.key,
    required this.searchPanel,
    required this.listings,
    required this.onListingTap,
    required this.onRetry,
    this.isLoading = false,
    this.hasError = false,
    this.selectedAreaLabel,
  });

  final Widget searchPanel;
  final List<Listing> listings;
  final ValueChanged<Listing> onListingTap;
  final VoidCallback onRetry;
  final bool isLoading;
  final bool hasError;
  final String? selectedAreaLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchPanel,
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 840;
                      if (!wide) {
                        return _FallbackResultsScroll(
                          listings: listings,
                          hasError: hasError,
                          isLoading: isLoading,
                          selectedAreaLabel: selectedAreaLabel,
                          onListingTap: onListingTap,
                          onRetry: onRetry,
                          includePreview: true,
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 4,
                            child: AppStaticMapPreview(
                              title: listings.isEmpty
                                  ? 'Explore parking from any screen'
                                  : '${listings.length} parking ${listings.length == 1 ? 'spot' : 'spots'} to explore',
                              message:
                                  'This is a privacy-safe area preview. Open '
                                  'Parkd on iOS or Android for the interactive map.',
                              pinCount: listings.length,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            flex: 6,
                            child: _FallbackResultsScroll(
                              listings: listings,
                              hasError: hasError,
                              isLoading: isLoading,
                              selectedAreaLabel: selectedAreaLabel,
                              onListingTap: onListingTap,
                              onRetry: onRetry,
                              includePreview: false,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackResultsScroll extends StatelessWidget {
  const _FallbackResultsScroll({
    required this.listings,
    required this.hasError,
    required this.isLoading,
    required this.selectedAreaLabel,
    required this.onListingTap,
    required this.onRetry,
    required this.includePreview,
  });

  final List<Listing> listings;
  final bool hasError;
  final bool isLoading;
  final String? selectedAreaLabel;
  final ValueChanged<Listing> onListingTap;
  final VoidCallback onRetry;
  final bool includePreview;

  @override
  Widget build(BuildContext context) {
    final area = selectedAreaLabel?.trim();
    return CustomScrollView(
      key: const Key('map-platform-fallback-results'),
      slivers: [
        if (includePreview) ...[
          SliverToBoxAdapter(
            child: SizedBox(
              height: 210,
              child: AppStaticMapPreview(
                title: listings.isEmpty
                    ? 'Browse parking without a map'
                    : '${listings.length} parking ${listings.length == 1 ? 'spot' : 'spots'} nearby',
                message:
                    'Search an area and choose a result below. Interactive maps '
                    'are available on iOS and Android.',
                pinCount: listings.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
        SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  area == null || area.isEmpty
                      ? 'Available parking'
                      : 'Parking near ${_shortAreaLabel(area)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.sectionTitle,
                ),
              ),
              if (listings.isNotEmpty)
                Text(
                  '${listings.length} ${listings.length == 1 ? 'result' : 'results'}',
                  style: AppTypography.caption,
                ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        if (hasError)
          SliverToBoxAdapter(
            child: _FallbackMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Parking spots could not be loaded',
              message: 'Check your connection, then try again.',
              actionLabel: 'Retry',
              onAction: onRetry,
            ),
          )
        else if (!isLoading && listings.isEmpty)
          const SliverToBoxAdapter(
            child: _FallbackMessageCard(
              icon: Icons.local_parking_outlined,
              title: 'No parking spots found',
              message: 'Try another area or widen the price filter.',
            ),
          )
        else
          SliverList.separated(
            itemCount: listings.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final listing = listings[index];
              return _FallbackListingCard(
                key: ValueKey('fallback-listing-${listing.id}'),
                listing: listing,
                onTap: () => onListingTap(listing),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      ],
    );
  }
}

class _FallbackListingCard extends StatelessWidget {
  const _FallbackListingCard({
    super.key,
    required this.listing,
    required this.onTap,
  });

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl = listing.heroPhotoUrl?.trim();
    final title = listing.isApproximateLocation
        ? listing.approximateAreaHeadline
        : (listing.address.trim().isEmpty
              ? 'Parking near ${listing.city}'
              : listing.address);
    final hourly = listing.minHourlyPrice;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.secondaryGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 126,
          child: Row(
              children: [
                SizedBox(
                  width: 132,
                  height: double.infinity,
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const _FallbackPhotoPlaceholder(),
                        )
                      : const _FallbackPhotoPlaceholder(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyStrong,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.iconGrey,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          listing.isApproximateLocation
                              ? (listing.spotLabel ?? 'Approximate area')
                              : (listing.townCountryLine.isNotEmpty
                                    ? listing.townCountryLine
                                    : listing.localityLine),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (listing.isApproximateLocation)
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.privacy_tip_outlined,
                                      size: 15,
                                      color: AppColors.primaryBlue,
                                    ),
                                    const SizedBox(width: AppSpacing.xxs),
                                    Expanded(
                                      child: Text(
                                        'Approximate location',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.captionLink,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Spacer(),
                            if (hourly != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'From \$${hourly.toStringAsFixed(hourly == hourly.roundToDouble() ? 0 : 2)}/hr',
                                style: AppTypography.captionStrong,
                              ),
                            ],
                          ],
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

class _FallbackPhotoPlaceholder extends StatelessWidget {
  const _FallbackPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.secondaryBlue,
      child: Center(
        child: Icon(
          Icons.local_parking_rounded,
          size: 34,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }
}

class _FallbackMessageCard extends StatelessWidget {
  const _FallbackMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondaryBlue.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.secondaryGrey),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(icon, size: 34, color: AppColors.primaryBlue),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMuted,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppPrimaryButton(
                label: actionLabel!,
                fullWidth: false,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _shortAreaLabel(String value) {
  final first = value.split(',').first.trim();
  return first.isEmpty ? value : first;
}

List<Listing> sortListingsNear({
  required List<Listing> listings,
  required double latitude,
  required double longitude,
}) {
  final sorted = List<Listing>.of(listings);
  sorted.sort((a, b) {
    final aDistance = _distanceSquared(a, latitude, longitude);
    final bDistance = _distanceSquared(b, latitude, longitude);
    return aDistance.compareTo(bDistance);
  });
  return sorted;
}

double _distanceSquared(Listing listing, double latitude, double longitude) {
  final latitudeDelta = listing.latitude - latitude;
  final longitudeDelta = listing.longitude - longitude;
  return latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
}
