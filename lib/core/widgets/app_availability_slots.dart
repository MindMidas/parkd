import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../utils/display_formatting.dart';
import 'app_buttons.dart';
import 'app_display_fields.dart';
import 'app_section_title.dart';

// Models + UI for showing listing availability (date ranges and/or weekly)

// From/to display strings + prices
class DateRangeSlot {
  const DateRangeSlot({
    required this.from,
    required this.to,
    required this.priceHour,
    this.priceDay,
  });
  final String from;
  final String to;
  final double priceHour;
  final double? priceDay;
}

// Day label + time range + prices
class WeeklySlot {
  const WeeklySlot({
    required this.day,
    required this.timeRange,
    required this.priceHour,
    this.priceDay,
  });
  final String day;
  final String timeRange;
  final double priceHour;
  final double? priceDay;
}

// Renders whichever lists you pass (empty list = that section hidden)
class AppAvailabilitySlots extends StatelessWidget {
  const AppAvailabilitySlots._({
    required this.title,
    this.onEdit,
    this.dateRangeSlots,
    this.weeklySlots,
    this.editButtonFullWidth = true,
    this.showTitle = true,
    this.useOuterPadding = true,
  });

  // Only date-range slots
  factory AppAvailabilitySlots.dateRanges({
    required List<DateRangeSlot> slots,
    String title = 'Scheduled time slots',
    VoidCallback? onEdit,
    bool editButtonFullWidth = true,
    bool showTitle = true,
    bool useOuterPadding = true,
  }) {
    return AppAvailabilitySlots._(
      title: title,
      onEdit: onEdit,
      dateRangeSlots: slots.isEmpty ? null : slots,
      editButtonFullWidth: editButtonFullWidth,
      showTitle: showTitle,
      useOuterPadding: useOuterPadding,
    );
  }

  // Only weekly slots
  factory AppAvailabilitySlots.weekly({
    required List<WeeklySlot> slots,
    String title = 'Scheduled time slots',
    VoidCallback? onEdit,
    bool editButtonFullWidth = true,
    bool showTitle = true,
    bool useOuterPadding = true,
  }) {
    return AppAvailabilitySlots._(
      title: title,
      onEdit: onEdit,
      weeklySlots: slots.isEmpty ? null : slots,
      editButtonFullWidth: editButtonFullWidth,
      showTitle: showTitle,
      useOuterPadding: useOuterPadding,
    );
  }

  // Date ranges first, then weekly (pass only non-empty lists from your data layer)
  factory AppAvailabilitySlots.combined({
    required String title,
    List<DateRangeSlot>? dateRangeSlots,
    List<WeeklySlot>? weeklySlots,
    VoidCallback? onEdit,
    bool editButtonFullWidth = true,
    bool showTitle = true,
    bool useOuterPadding = true,
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
      showTitle: showTitle,
      useOuterPadding: useOuterPadding,
    );
  }

  final String title;
  final VoidCallback? onEdit;
  final List<DateRangeSlot>? dateRangeSlots;
  final List<WeeklySlot>? weeklySlots;
  final bool editButtonFullWidth;
  final bool showTitle;
  final bool useOuterPadding;

  static const double _editButtonWidth = 92;

  // Scroll area max heights (~3 rows)
  static const double _scrollViewportDateMaxHeight = 360;
  static const double _scrollViewportWeeklyMaxHeight = 280;
  static const int _maxSlotsBeforeScroll = 3;

  // "Sep 15, 2026 • 9:00 AM" -> date + time
  static (String date, String time) splitDateAndTime(String fromOrTo) =>
      splitDisplayDateTime(fromOrTo);

  @override
  Widget build(BuildContext context) {
    final hasDateRange = dateRangeSlots != null && dateRangeSlots!.isNotEmpty;
    final hasWeekly = weeklySlots != null && weeklySlots!.isNotEmpty;

    final dateRangeChildren = <Widget>[];
    if (hasDateRange) {
      for (final slot in dateRangeSlots!) {
        final from = splitDateAndTime(slot.from);
        final to = splitDateAndTime(slot.to);
        dateRangeChildren.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppDisplayOutlineCard(
              child: AppAvailabilityDateRangeSlotBlock(
                fromDate: from.$1,
                fromTime: from.$2,
                toDate: to.$1,
                toTime: to.$2,
                priceHour: slot.priceHour,
                priceDay: slot.priceDay,
              ),
            ),
          ),
        );
      }
    }

    final weeklyChildren = <Widget>[];
    if (hasWeekly) {
      for (final slot in weeklySlots!) {
        weeklyChildren.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppDisplayOutlineCard(
              child: AppAvailabilityWeeklySlotBlock(
                day: slot.day,
                timeRange: slot.timeRange,
                priceHour: slot.priceHour,
                priceDay: slot.priceDay,
              ),
            ),
          ),
        );
      }
    }

    Widget scrollableSlotStack(
      List<Widget> items,
      int count, {
      required double viewportHeight,
    }) {
      if (items.isEmpty) return const SizedBox.shrink();
      if (count > _maxSlotsBeforeScroll) {
        return SizedBox(
          height: viewportHeight,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: items,
            ),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: items,
      );
    }

    final Widget slotsSection;
    if (!hasDateRange && !hasWeekly) {
      slotsSection = const SizedBox.shrink();
    } else {
      slotsSection = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          scrollableSlotStack(
            dateRangeChildren,
            hasDateRange ? dateRangeSlots!.length : 0,
            viewportHeight: _scrollViewportDateMaxHeight,
          ),
          if (dateRangeChildren.isNotEmpty && weeklyChildren.isNotEmpty)
            const SizedBox(height: AppSpacing.sm),
          scrollableSlotStack(
            weeklyChildren,
            hasWeekly ? weeklySlots!.length : 0,
            viewportHeight: _scrollViewportWeeklyMaxHeight,
          ),
        ],
      );
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          AppSectionTitle(title),
          const SizedBox(height: AppSpacing.md),
        ],
        slotsSection,
        if (onEdit != null) ...[
          const SizedBox(height: AppSpacing.md),
          editButtonFullWidth
              ? AppPrimaryButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                )
              : SizedBox(
                  width: _editButtonWidth,
                  child: AppPrimaryButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    onPressed: onEdit,
                    fullWidth: false,
                  ),
                ),
        ],
      ],
    );
    if (useOuterPadding) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: content,
      );
    }
    return content;
  }
}
