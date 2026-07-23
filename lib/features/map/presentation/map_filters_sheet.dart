import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/map/map_filters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_ink.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/time_step_minutes.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/map_providers.dart';

void showMapFiltersSheet(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  AppModalSheet.show<void>(
    context: context,
    builder: (sheetContext) => AppModalSheet(
      maxHeightFraction: 0.88,
      padding: EdgeInsets.zero,
      footer: AppStickyFooter(
        child: AppPrimaryButton(
          label: 'Done',
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ),
      child: const SingleChildScrollView(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: _MapFiltersSheetBody(),
      ),
    ),
  );
}

class _FilterToggleRow extends StatelessWidget {
  const _FilterToggleRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppInk.splashSoft,
        highlightColor: AppInk.highlight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.body),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: AppTypography.bodyMuted),
                  ],
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapFiltersSheetBody extends ConsumerStatefulWidget {
  const _MapFiltersSheetBody();

  @override
  ConsumerState<_MapFiltersSheetBody> createState() =>
      _MapFiltersSheetBodyState();
}

class _MapFiltersSheetBodyState extends ConsumerState<_MapFiltersSheetBody> {
  late DateTime _currentMonth;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final selected = ref.read(mapFiltersProvider).availRangeStart;
    final anchor = selected ?? DateTime.now();
    _currentMonth = DateTime(anchor.year, anchor.month);
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Set<DateTime> _selectedDates(MapFilters filters) {
    final rangeStart = filters.availRangeStart;
    final rangeEnd = filters.availRangeEnd;
    if (rangeStart == null || rangeEnd == null) {
      if (rangeStart == null) return {};
      return {DateTime(rangeStart.year, rangeStart.month, rangeStart.day)};
    }

    final start = rangeStart.isBefore(rangeEnd) ? rangeStart : rangeEnd;
    final end = rangeStart.isAfter(rangeEnd) ? rangeStart : rangeEnd;
    final selected = <DateTime>{};
    var day = DateTime(start.year, start.month, start.day);
    final lastDay = DateTime(end.year, end.month, end.day);
    while (!day.isAfter(lastDay)) {
      selected.add(day);
      day = day.add(const Duration(days: 1));
    }
    return selected;
  }

  bool _isDateSelectable(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(_today);
  }

  void _onDayTap(MapFilters filters, DateTime date) {
    final tapped = DateTime(date.year, date.month, date.day);
    if (!_isDateSelectable(tapped)) return;

    final currentStart = filters.availRangeStart;
    final currentEnd = filters.availRangeEnd;
    late DateTime nextStart;
    late DateTime nextEnd;
    final hasRange = currentStart != null && currentEnd != null;
    final isSingleDay = hasRange && _sameCalendarDay(currentStart, currentEnd);

    if (!hasRange) {
      nextStart = tapped;
      nextEnd = tapped;
    } else if (isSingleDay) {
      if (tapped.isBefore(currentStart)) {
        nextStart = tapped;
        nextEnd = currentStart;
      } else {
        nextStart = currentStart;
        nextEnd = tapped;
      }
    } else {
      nextStart = tapped;
      nextEnd = tapped;
    }

    ref.read(mapFiltersProvider.notifier).setAvailRange(nextStart, nextEnd);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final filters = ref.read(mapFiltersProvider);
    final initial = isStart
        ? filters.availStartMinutes
        : filters.availEndMinutes;
    final picked = await showAppTimePickerMinutes(
      context: context,
      initialMinutes: initial,
    );
    if (picked == null || !mounted) return;

    final notifier = ref.read(mapFiltersProvider.notifier);
    if (isStart) {
      notifier.setAvailStartMinutes(picked);
    } else {
      notifier.setAvailEndMinutes(picked);
    }
  }

  String _proximitySectionTitle(MapFilters filters) {
    if (!filters.proximityEnabled) return 'Proximity';
    return 'Proximity · ${filters.proximityRadiusKm.toStringAsFixed(0)} km';
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(mapFiltersProvider);
    final notifier = ref.read(mapFiltersProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionTitle('Map filters'),
              SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        AppScreenSection(
          title: 'Price',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Max price per hour: \$${filters.maxPricePerHour.toStringAsFixed(0)}',
                style: AppTypography.body,
              ),
              Slider(
                value: filters.maxPricePerHour.clamp(5, 50),
                min: 5,
                max: 50,
                divisions: 9,
                label: '\$${filters.maxPricePerHour.toStringAsFixed(0)}',
                onChanged: notifier.setMaxPricePerHour,
              ),
            ],
          ),
        ),
        AppScreenSection(
          dividerAbove: true,
          title: _proximitySectionTitle(filters),
          description:
              'Uses your current position and each listing’s approximate public location.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterToggleRow(
                title: 'Near my location',
                subtitle:
                    'If location access is unavailable, Parkd leaves results unfiltered.',
                value: filters.proximityEnabled,
                onChanged: notifier.setProximityEnabled,
              ),
              if (filters.proximityEnabled)
                Slider(
                  value: filters.proximityRadiusKm.clamp(1, 50),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  label: '${filters.proximityRadiusKm.toStringAsFixed(0)} km',
                  onChanged: notifier.setProximityRadiusKm,
                ),
            ],
          ),
        ),
        AppScreenSection(
          dividerAbove: true,
          title: 'Availability',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterToggleRow(
                title: 'Filter by calendar & time',
                subtitle:
                    'Only show spots open and unbooked for the complete window.',
                value: filters.availabilityFilterEnabled,
                onChanged: notifier.setAvailabilityFilterEnabled,
              ),
              if (filters.availabilityFilterEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                AppListingSpecificDatesInputCard(
                  title: 'Dates & times',
                  calendar: AppMonthCalendar(
                    currentMonth: _currentMonth,
                    selectedDates: _selectedDates(filters),
                    minDate: _today,
                    isDateSelectable: _isDateSelectable,
                    onPrevMonth: () => setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    }),
                    onNextMonth: () => setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month + 1,
                      );
                    }),
                    onDayTap: (date) => _onDayTap(filters, date),
                  ),
                  startValue: TimeStepMinutes.formatAmPm(
                    filters.availStartMinutes,
                  ),
                  endValue: TimeStepMinutes.formatAmPm(filters.availEndMinutes),
                  onStartTap: () => _pickTime(isStart: true),
                  onEndTap: () => _pickTime(isStart: false),
                  showAddSlotButton: false,
                ),
                if (!filters.hasValidAvailabilityWindow) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppFormHelperText(
                    filters.availRangeStart == null ||
                            filters.availRangeEnd == null
                        ? 'Select at least one day to apply this filter.'
                        : 'The end of the window must be after its start.',
                  ),
                ],
              ],
            ],
          ),
        ),
        AppScreenSection(
          dividerAbove: true,
          title: 'Area',
          child: _FilterToggleRow(
            title: 'Guelph listings only',
            subtitle: 'When off, show every published listing.',
            value: filters.guelphOnly,
            onChanged: notifier.setGuelphOnly,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
