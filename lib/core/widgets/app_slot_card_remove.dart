import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_display_fields.dart';

// Slot row with blue X to remove; child is weekly or date-range content
class AppSlotCardRemove extends StatelessWidget {
  const AppSlotCardRemove({
    super.key,
    required this.child,
    required this.onRemove,
  });

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: AppDisplayOutlineCard(child: child)),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Date-range block for inside AppSlotCardRemove
class AppSlotCardRemoveDateRange extends StatelessWidget {
  const AppSlotCardRemoveDateRange({
    super.key,
    required this.from,
    required this.to,
    required this.priceHour,
    this.priceDay,
  });

  final String from;
  final String to;
  final double priceHour;
  final double? priceDay;

  @override
  Widget build(BuildContext context) {
    return AppAvailabilityDateRangeSlotBlock.fromSlotStrings(
      from: from,
      to: to,
      priceHour: priceHour,
      priceDay: priceDay,
    );
  }
}

// Weekly block for inside AppSlotCardRemove (same layout as availability weekly block)
class AppSlotCardRemoveWeekly extends StatelessWidget {
  const AppSlotCardRemoveWeekly({
    super.key,
    required this.day,
    required this.timeRange,
    required this.priceHour,
    this.priceDay,
  });

  final String day;
  final String timeRange;
  final double priceHour;
  final double? priceDay;

  @override
  Widget build(BuildContext context) {
    return AppAvailabilityWeeklySlotBlock(
      day: day,
      timeRange: timeRange,
      priceHour: priceHour,
      priceDay: priceDay,
    );
  }
}
