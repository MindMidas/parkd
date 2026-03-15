import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_availability_slots.dart';

/// Card showing a single scheduled slot (date-range or weekly) with a remove (X) button. Reusable in set-availability screens.
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
          Expanded(
            child: _SlotCard(child: child),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Date-range slot content for [AppSlotCardRemove]: From / To with date and time.
class AppSlotCardRemoveDateRange extends StatelessWidget {
  const AppSlotCardRemoveDateRange({
    super.key,
    required this.from,
    required this.to,
  });

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final (fromDate, fromTime) = AppAvailabilitySlots.splitDateAndTime(from);
    final (toDate, toTime) = AppAvailabilitySlots.splitDateAndTime(to);
    final labelStyle = TextStyle(
      fontSize: 12,
      color: AppColors.textSecondary,
    );
    final valueStyle = TextStyle(
      fontSize: 14,
      color: AppColors.textPrimary,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From', style: labelStyle),
              const SizedBox(height: 2),
              Text(fromDate, style: valueStyle),
              if (fromTime.isNotEmpty) Text(fromTime, style: valueStyle),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('To', style: labelStyle),
              const SizedBox(height: 2),
              Text(toDate, style: valueStyle),
              if (toTime.isNotEmpty) Text(toTime, style: valueStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// Weekly slot content for [AppSlotCardRemove]: day + time range.
class AppSlotCardRemoveWeekly extends StatelessWidget {
  const AppSlotCardRemoveWeekly({
    super.key,
    required this.day,
    required this.timeRange,
  });

  final String day;
  final String timeRange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          timeRange,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondaryGrey.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
