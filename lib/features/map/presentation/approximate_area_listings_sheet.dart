import 'package:flutter/material.dart';

import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';

// Picker when an approximate map area contains more than one listing.
Future<Listing?> showApproximateAreaListingsSheet(
  BuildContext context, {
  required List<Listing> listings,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final sorted = [...listings]
    ..sort((a, b) {
      final priceA = a.minHourlyPrice ?? double.infinity;
      final priceB = b.minHourlyPrice ?? double.infinity;
      final byPrice = priceA.compareTo(priceB);
      if (byPrice != 0) return byPrice;
      return a.id.compareTo(b.id);
    });
  return AppModalSheet.show<Listing>(
    context: context,
    builder: (sheetContext) => AppModalSheet(
      maxHeightFraction: 0.55,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parking in this area',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${sorted.length} spots in this area — exact addresses '
                  'are shared after a reservation is confirmed.',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const AppDividerWide(),
              itemBuilder: (context, index) {
                final listing = sorted[index];
                final hourly = listing.minHourlyPrice;
                final priceLabel = hourly == null
                    ? 'See pricing'
                    : 'From \$${hourly.toStringAsFixed(hourly == hourly.roundToDouble() ? 0 : 2)}/hr';
                return AppMenuRow(
                  title: listing.approximateAreaHeadline,
                  subtitle: listing.spotLabel ?? 'Approximate area',
                  onTap: () => Navigator.of(sheetContext).pop(listing),
                  rightKind: AppMenuRightKind.none,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        priceLabel,
                        style: AppTypography.captionStrong,
                      ),
                      const SizedBox(width: AppSpacing.xxs),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.iconGrey,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
