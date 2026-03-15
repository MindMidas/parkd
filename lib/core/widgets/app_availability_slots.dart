import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

/// One date-range slot: "From" and "To" date/time strings (e.g. "Sep 15, 2026 • 9:00 AM").
class DateRangeSlot {
  const DateRangeSlot({required this.from, required this.to});
  final String from;
  final String to;
}

/// One weekly slot: day abbreviation and time range (e.g. "Mon", "9:15 AM to 1:00 PM").
class WeeklySlot {
  const WeeklySlot({required this.day, required this.timeRange});
  final String day;
  final String timeRange;
}

/// Renders scheduled availability: date ranges (From/To), weekly (day + time), or both.
/// When wired to Supabase, pass only the non-empty list(s); widget shows whichever format has data.
class AppAvailabilitySlots extends StatelessWidget {
  const AppAvailabilitySlots._({
    required this.title,
    this.onEdit,
    this.dateRangeSlots,
    this.weeklySlots,
    this.editButtonFullWidth = true,
  });

  /// Date-range only: each slot shows "From" and "To" with date on first line, time below.
  factory AppAvailabilitySlots.dateRanges({
    required List<DateRangeSlot> slots,
    String title = 'Scheduled time slots',
    VoidCallback? onEdit,
    bool editButtonFullWidth = true,
  }) {
    return AppAvailabilitySlots._(
      title: title,
      onEdit: onEdit,
      dateRangeSlots: slots.isEmpty ? null : slots,
      editButtonFullWidth: editButtonFullWidth,
    );
  }

  /// Weekly only: each slot shows day (left) and time range (right) in a card.
  factory AppAvailabilitySlots.weekly({
    required List<WeeklySlot> slots,
    String title = 'Scheduled time slots',
    VoidCallback? onEdit,
    bool editButtonFullWidth = true,
  }) {
    return AppAvailabilitySlots._(
      title: title,
      onEdit: onEdit,
      weeklySlots: slots.isEmpty ? null : slots,
      editButtonFullWidth: editButtonFullWidth,
    );
  }

  /// Both formats: show date-range slots first, then weekly. When wired to Supabase, pass only non-empty list(s) from getAvailabilitySpecific / getAvailabilityWeekly so the UI shows the right format(s) automatically.
  factory AppAvailabilitySlots.combined({
    required String title,
    List<DateRangeSlot>? dateRangeSlots,
    List<WeeklySlot>? weeklySlots,
    VoidCallback? onEdit,
    bool editButtonFullWidth = true,
  }) {
    return AppAvailabilitySlots._(
      title: title,
      onEdit: onEdit,
      dateRangeSlots: dateRangeSlots != null && dateRangeSlots.isNotEmpty
          ? dateRangeSlots
          : null,
      weeklySlots: weeklySlots != null && weeklySlots.isNotEmpty
          ? weeklySlots
          : null,
      editButtonFullWidth: editButtonFullWidth,
    );
  }

  final String title;
  final VoidCallback? onEdit;
  final List<DateRangeSlot>? dateRangeSlots;
  final List<WeeklySlot>? weeklySlots;
  final bool editButtonFullWidth;

  static const double _editButtonWidth = 92;

  /// Splits "Sep 15, 2026 • 9:00 AM" into ("Sep 15, 2026", "9:00 AM").
  static (String date, String time) splitDateAndTime(String fromOrTo) {
    final i = fromOrTo.indexOf(' • ');
    if (i >= 0) {
      return (fromOrTo.substring(0, i).trim(), fromOrTo.substring(i + 3).trim());
    }
    return (fromOrTo, '');
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTypography.caption.copyWith(
      color: AppColors.textSecondary,
    );
    final valueStyleSmall = AppTypography.caption.copyWith(
      color: AppColors.textPrimary,
      fontSize: 12,
    );
    final valueStyleWeekly = AppTypography.body;

    final hasDateRange = dateRangeSlots != null && dateRangeSlots!.isNotEmpty;
    final hasWeekly = weeklySlots != null && weeklySlots!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (hasDateRange)
            ...dateRangeSlots!.map(
              (slot) {
                final from = splitDateAndTime(slot.from);
                final to = splitDateAndTime(slot.to);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _SlotCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('From', style: labelStyle),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(from.$1, style: valueStyleSmall),
                              if (from.$2.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(from.$2, style: valueStyleSmall),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('To', style: labelStyle),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(to.$1, style: valueStyleSmall),
                              if (to.$2.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(to.$2, style: valueStyleSmall),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (hasWeekly) ...[
            if (hasDateRange) const SizedBox(height: AppSpacing.sm),
            ...weeklySlots!.map(
              (slot) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _SlotCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        slot.day,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(slot.timeRange, style: valueStyleWeekly),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (onEdit != null) ...[
            const SizedBox(height: AppSpacing.md),
            editButtonFullWidth
                ? AppPrimaryButton(
                    label: 'Edit',
                    onPressed: onEdit,
                  )
                : SizedBox(
                    width: _editButtonWidth,
                    child: AppPrimaryButton(
                      label: 'Edit',
                      onPressed: onEdit,
                    ),
                  ),
          ],
        ],
      ),
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
        border: Border.all(color: AppColors.secondaryGrey.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
