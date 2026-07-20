import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/time_step_minutes.dart';
import 'app_availability_slots.dart';
import 'app_buttons.dart';
import 'app_day_checkboxes.dart';
import 'app_display_fields.dart';
import 'app_info_text.dart';
import 'app_price_stepper.dart';
import 'app_slot_card_remove.dart';
import 'app_time_picker_row.dart';
import 'app_time_picker_sheet.dart';

// Titled cards for listing edit flows (availability, price, slots)

// Shows current availability + Edit
class AppListingEditAvailabilityCard extends StatelessWidget {
  const AppListingEditAvailabilityCard({
    super.key,
    required this.onEdit,
    required this.dateRangeSlots,
    required this.weeklySlots,
    this.title = 'Availability and Price',
  });

  final VoidCallback onEdit;
  final List<DateRangeSlot> dateRangeSlots;
  final List<WeeklySlot> weeklySlots;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppAvailabilitySlots.combined(
            title: title,
            dateRangeSlots: dateRangeSlots,
            weeklySlots: weeklySlots,
            onEdit: null,
            editButtonFullWidth: true,
            showTitle: false,
            useOuterPadding: false,
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

// Delete listing CTA + warning
class AppListingDeleteCard extends StatelessWidget {
  const AppListingDeleteCard({
    super.key,
    required this.onDelete,
    this.title = 'Delete listing',
    this.hint = 'This action is irreversible',
  });

  final VoidCallback onDelete;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(hint, style: AppTypography.caption),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: 'Delete',
            icon: Icons.delete_outline_rounded,
            onPressed: onDelete,
            destructive: true,
          ),
        ],
      ),
    );
  }
}

// Hourly/daily price steppers + optional daily rate
class AppListingModifyPriceCard extends StatelessWidget {
  const AppListingModifyPriceCard({
    super.key,
    required this.hourly,
    required this.daily,
    required this.onHourlyChanged,
    required this.onDailyChanged,
    this.title = 'Choose how much drivers pay',
    // First daily value when they tap "Add daily rate"
    this.dailySeedWhenAdding = 30,
  });

  final int hourly;
  // null = no daily rate in DB
  final int? daily;
  final ValueChanged<num> onHourlyChanged;
  final ValueChanged<int?> onDailyChanged;
  final String title;
  final int dailySeedWhenAdding;

  static const _pricingFootnote =
      'Bookings over 24 hours are charged the cheaper of your hourly total '
      'or your daily rate (if you add one).';

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPriceStepper(
            label: 'Hourly price',
            value: hourly,
            min: 0,
            max: 999,
            onChanged: onHourlyChanged,
          ),
          if (daily == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Daily price (optional)',
                      style: AppTypography.bodyStrong,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        onDailyChanged(dailySeedWhenAdding.clamp(1, 9999)),
                    child: Text(
                      'Add daily rate',
                      style: AppTypography.textAction,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPriceStepper(
                  label: 'Daily price (optional)',
                  value: daily!,
                  min: 1,
                  max: 9999,
                  onChanged: (v) {
                    final n = v.toInt().clamp(1, 9999);
                    onDailyChanged(n);
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => onDailyChanged(null),
                    child: Text(
                      'Remove daily rate',
                      style: AppTypography.textAction,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          AppInfoText(_pricingFootnote),
        ],
      ),
    );
  }
}

// Summary lines for scheduled slots + Edit
class AppListingScheduledSlotsCard extends StatelessWidget {
  const AppListingScheduledSlotsCard({
    super.key,
    required this.slots,
    required this.onEdit,
    this.title = 'Scheduled time slots',
  });

  final List<String> slots;
  final VoidCallback onEdit;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (slots.isEmpty)
            Text(
              'No scheduled slots',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            )
          else
            ...slots.asMap().entries.map((entry) {
              final index = entry.key;
              final slot = entry.value;
              final parts = slot.split(RegExp(r'\s{2,}'));
              final left = parts.first.trim();
              final right = parts.length > 1 ? parts.last.trim() : '';
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == slots.length - 1 ? 0 : AppSpacing.sm,
                ),
                child: AppDisplayOutlineCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(left, style: AppTypography.bodyStrong),
                      ),
                      if (right.isNotEmpty)
                        Expanded(
                          child: Text(
                            right,
                            style: AppTypography.body,
                            textAlign: TextAlign.right,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

// Calendar + start/end time rows + optional Add slot (same time row pattern as weekly card)
class AppListingSpecificDatesInputCard extends StatelessWidget {
  const AppListingSpecificDatesInputCard({
    super.key,
    required this.calendar,
    required this.startValue,
    required this.endValue,
    required this.onStartTap,
    required this.onEndTap,
    this.onAddSlot,
    this.addEnabled = true,
    this.showAddSlotButton = true,
    this.title = 'Specific dates',
    this.startLabel = 'Start time',
    this.endLabel = 'End time',
  });

  final Widget calendar;
  final String startValue;
  final String endValue;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;
  final VoidCallback? onAddSlot;
  final bool addEnabled;
  // false = hide Add slot (e.g. reservation)
  final bool showAddSlotButton;
  final String title;
  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          calendar,
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: AppTimePickerRow(
              label: startLabel,
              value: startValue,
              labelWidth: 120,
              onTap: onStartTap,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: AppTimePickerRow(
              label: endLabel,
              value: endValue,
              labelWidth: 120,
              onTap: onEndTap,
            ),
          ),
          if (showAddSlotButton) ...[
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: 'Add slot',
              icon: Icons.add_rounded,
              onPressed: (addEnabled && onAddSlot != null) ? onAddSlot : null,
            ),
          ],
        ],
      ),
    );
  }
}

// Weekly days + start/end times + Add slot; onAddSlot gets AM/PM strings from internal state
class AppListingWeeklyScheduleInputCard extends StatefulWidget {
  const AppListingWeeklyScheduleInputCard({
    super.key,
    required this.selectedDayIndices,
    required this.onDaysChanged,
    required this.onAddSlot,
    this.addEnabled = true,
    this.title = 'Weekly schedule',
    this.startLabel = 'Start time',
    this.endLabel = 'End time',
    this.initialStartMinutes,
    this.initialEndMinutes,
  });

  final Set<int> selectedDayIndices;
  final ValueChanged<Set<int>> onDaysChanged;

  // Add slot gets AM/PM strings from the internal time pickers
  final void Function(String startTimeLabel, String endTimeLabel) onAddSlot;

  final bool addEnabled;
  final String title;
  final String startLabel;
  final String endLabel;

  // null -> 9:15 and 3:00 PM defaults
  final int? initialStartMinutes;
  final int? initialEndMinutes;

  @override
  State<AppListingWeeklyScheduleInputCard> createState() =>
      _AppListingWeeklyScheduleInputCardState();
}

class _AppListingWeeklyScheduleInputCardState
    extends State<AppListingWeeklyScheduleInputCard> {
  late int _startMinutes;
  late int _endMinutes;

  @override
  void initState() {
    super.initState();
    _startMinutes = widget.initialStartMinutes ?? (9 * 60 + 15);
    _endMinutes = widget.initialEndMinutes ?? (15 * 60);
  }

  @override
  void didUpdateWidget(covariant AppListingWeeklyScheduleInputCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStartMinutes != oldWidget.initialStartMinutes &&
        widget.initialStartMinutes != null) {
      _startMinutes = widget.initialStartMinutes!;
    }
    if (widget.initialEndMinutes != oldWidget.initialEndMinutes &&
        widget.initialEndMinutes != null) {
      _endMinutes = widget.initialEndMinutes!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDisplayTitledOutlineCard(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDayCheckboxes(
            selectedIndices: widget.selectedDayIndices,
            onChanged: widget.onDaysChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: AppTimePickerRow(
              label: widget.startLabel,
              value: TimeStepMinutes.formatAmPm(_startMinutes),
              labelWidth: 100,
              onTap: () async {
                final m = await showAppTimePickerMinutes(
                  context: context,
                  initialMinutes: _startMinutes,
                );
                if (m != null && context.mounted) {
                  setState(() => _startMinutes = m);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: AppTimePickerRow(
              label: widget.endLabel,
              value: TimeStepMinutes.formatAmPm(_endMinutes),
              labelWidth: 100,
              onTap: () async {
                final m = await showAppTimePickerMinutes(
                  context: context,
                  initialMinutes: _endMinutes,
                );
                if (m != null && context.mounted) {
                  setState(() => _endMinutes = m);
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Add slot',
            icon: Icons.add_rounded,
            onPressed: widget.addEnabled
                ? () => widget.onAddSlot(
                    TimeStepMinutes.formatAmPm(_startMinutes),
                    TimeStepMinutes.formatAmPm(_endMinutes),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// List of weekly slots with remove (scrolls if many)
class AppListingWeeklyScheduledSlotsCard extends StatelessWidget {
  const AppListingWeeklyScheduledSlotsCard({
    super.key,
    required this.slots,
    required this.onRemove,
    this.onTapSlot,
    this.trailingBuilder,
    this.title = 'Scheduled time slots',
    this.emptyLabel = 'No scheduled slots',
  });

  final List<
    ({String day, String timeRange, double priceHour, double? priceDay})
  >
  slots;
  final ValueChanged<int> onRemove;
  final ValueChanged<int>? onTapSlot;
  final Widget Function(int index)? trailingBuilder;
  final String title;
  final String emptyLabel;

  // ~3 one-line rows then scroll inside the card
  static const double _scrollViewportMaxHeight = 220;
  static const int _maxSlotsBeforeScroll = 3;

  @override
  Widget build(BuildContext context) {
    final slotItems = List.generate(slots.length, (i) {
      final s = slots[i];
      return GestureDetector(
        onTap: onTapSlot == null ? null : () => onTapSlot!(i),
        child: AppSlotCardRemove(
          onRemove: () => onRemove(i),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppSlotCardRemoveWeekly(
                  day: s.day,
                  timeRange: s.timeRange,
                  priceHour: s.priceHour,
                  priceDay: s.priceDay,
                ),
              ),
              if (trailingBuilder != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailingBuilder!(i),
              ],
            ],
          ),
        ),
      );
    });

    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (slots.isEmpty)
            Text(
              emptyLabel,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            )
          else if (slots.length > _maxSlotsBeforeScroll)
            SizedBox(
              height: _scrollViewportMaxHeight,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: slotItems,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: slotItems,
            ),
        ],
      ),
    );
  }
}

// List of date-range slots with remove
class AppListingSpecificDateSlotsCard extends StatelessWidget {
  const AppListingSpecificDateSlotsCard({
    super.key,
    required this.slots,
    required this.onRemove,
    this.onTapSlot,
    this.trailingBuilder,
    this.title = 'Scheduled time slots',
    this.emptyLabel = 'No scheduled slots',
  });

  final List<({String from, String to, double priceHour, double? priceDay})>
  slots;
  final ValueChanged<int> onRemove;
  final ValueChanged<int>? onTapSlot;
  final Widget Function(int index)? trailingBuilder;
  final String title;
  final String emptyLabel;

  static const double _scrollViewportMaxHeight = 300;
  static const int _maxSlotsBeforeScroll = 3;

  @override
  Widget build(BuildContext context) {
    final slotItems = List.generate(slots.length, (i) {
      final s = slots[i];
      return GestureDetector(
        onTap: onTapSlot == null ? null : () => onTapSlot!(i),
        child: AppSlotCardRemove(
          onRemove: () => onRemove(i),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppAvailabilityDateRangeSlotBlock.fromSlotStrings(
                  from: s.from,
                  to: s.to,
                  priceHour: s.priceHour,
                  priceDay: s.priceDay,
                ),
              ),
              if (trailingBuilder != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailingBuilder!(i),
              ],
            ],
          ),
        ),
      );
    });

    return AppDisplayTitledOutlineCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (slots.isEmpty)
            Text(
              emptyLabel,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            )
          else if (slots.length > _maxSlotsBeforeScroll)
            SizedBox(
              height: _scrollViewportMaxHeight,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: slotItems,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: slotItems,
            ),
        ],
      ),
    );
  }
}
