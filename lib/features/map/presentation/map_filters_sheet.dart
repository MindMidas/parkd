import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/map/map_filters.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/time_step_minutes.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/map_providers.dart';

void showMapFiltersSheet(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      final h = MediaQuery.sizeOf(ctx).height * 0.88;
      return SizedBox(
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: const _MapFiltersSheetBody(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: AppPrimaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _MapFiltersSheetBody extends ConsumerStatefulWidget {
  const _MapFiltersSheetBody();

  @override
  ConsumerState<_MapFiltersSheetBody> createState() =>
      _MapFiltersSheetBodyState();
}

class _MapFiltersSheetBodyState extends ConsumerState<_MapFiltersSheetBody> {
  late DateTime _currentMonth;

  DateTime get _today =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Set<DateTime> _selectedDates(MapFilters f) {
    if (f.availRangeStart == null || f.availRangeEnd == null) {
      if (f.availRangeStart != null) {
        return {
          DateTime(
            f.availRangeStart!.year,
            f.availRangeStart!.month,
            f.availRangeStart!.day,
          ),
        };
      }
      return {};
    }
    final start = f.availRangeStart!.isBefore(f.availRangeEnd!)
        ? f.availRangeStart!
        : f.availRangeEnd!;
    final end = f.availRangeStart!.isAfter(f.availRangeEnd!)
        ? f.availRangeStart!
        : f.availRangeEnd!;
    final set = <DateTime>{};
    var d = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(endDate)) {
      set.add(d);
      d = d.add(const Duration(days: 1));
    }
    return set;
  }

  bool _isDateSelectable(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    return !dayOnly.isBefore(_today);
  }

  void _onDayTap(MapFilters f, DateTime date) {
    final tap = DateTime(date.year, date.month, date.day);
    if (!_isDateSelectable(tap)) return;

    final rs = f.availRangeStart;
    final re = f.availRangeEnd;
    late DateTime ns;
    late DateTime ne;

    final had = rs != null && re != null;
    final collapsed = had && _sameCalendarDay(rs, re);

    if (!had) {
      ns = ne = tap;
    } else if (collapsed) {
      final anchor = rs;
      if (tap.isBefore(anchor)) {
        ns = tap;
        ne = anchor;
      } else {
        ns = anchor;
        ne = tap;
      }
    } else {
      ns = ne = tap;
    }

    if (ns.isAfter(ne)) {
      final t = ns;
      ns = ne;
      ne = t;
    }

    ref.read(mapFiltersProvider.notifier).setAvailRange(ns, ne);
  }

  bool _availabilityWindowValid(MapFilters f) {
    if (f.availRangeStart == null || f.availRangeEnd == null) return false;
    final rs = f.availRangeStart!;
    final re = f.availRangeEnd!;
    final globalStart =
        DateTime(rs.year, rs.month, rs.day).add(Duration(minutes: f.availStartMinutes));
    final globalEnd =
        DateTime(re.year, re.month, re.day).add(Duration(minutes: f.availEndMinutes));
    return globalEnd.isAfter(globalStart);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final f = ref.read(mapFiltersProvider);
    final initial = isStart ? f.availStartMinutes : f.availEndMinutes;
    final picked = await showAppTimePickerMinutes(
      context: context,
      initialMinutes: initial,
    );
    if (picked != null && mounted) {
      final n = ref.read(mapFiltersProvider.notifier);
      if (isStart) {
        n.setAvailStartMinutes(picked);
      } else {
        n.setAvailEndMinutes(picked);
      }
    }
  }

  String _proximitySectionTitle(MapFilters f) {
    if (f.proximityEnabled) {
      return 'Proximity · ${f.proximityRadiusKm.toStringAsFixed(0)} km';
    }
    return 'Proximity';
  }

  @override
  Widget build(BuildContext context) {
    final f = ref.watch(mapFiltersProvider);
    final n = ref.read(mapFiltersProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppSectionTitle('Map filters'),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        AppScreenSection(
          title: 'Price',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Max price per hour: \$${f.maxPricePerHour.toStringAsFixed(0)}',
                style: AppTypography.body,
              ),
              Slider(
                value: f.maxPricePerHour.clamp(5, 50),
                min: 5,
                max: 50,
                divisions: 9,
                onChanged: n.setMaxPricePerHour,
              ),
            ],
          ),
        ),
        AppScreenSection(
          dividerAbove: true,
          title: _proximitySectionTitle(f),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Near my location'),
                value: f.proximityEnabled,
                onChanged: n.setProximityEnabled,
              ),
              if (f.proximityEnabled)
                Slider(
                  value: f.proximityRadiusKm.clamp(1, 50),
                  min: 1,
                  max: 50,
                  divisions: 49,
                  onChanged: n.setProximityRadiusKm,
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Filter by calendar & time'),
                value: f.availabilityFilterEnabled,
                onChanged: n.setAvailabilityFilterEnabled,
              ),
              if (f.availabilityFilterEnabled) ...[
                const SizedBox(height: AppSpacing.md),
                AppListingSpecificDatesInputCard(
                  title: 'Dates & times',
                  calendar: AppMonthCalendar(
                    currentMonth: _currentMonth,
                    selectedDates: _selectedDates(f),
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
                    onPrevYear: () => setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year - 1,
                        _currentMonth.month,
                      );
                    }),
                    onNextYear: () => setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year + 1,
                        _currentMonth.month,
                      );
                    }),
                    onDayTap: (d) => _onDayTap(f, d),
                  ),
                  startValue: TimeStepMinutes.formatAmPm(f.availStartMinutes),
                  endValue: TimeStepMinutes.formatAmPm(f.availEndMinutes),
                  onStartTap: () => _pickTime(isStart: true),
                  onEndTap: () => _pickTime(isStart: false),
                  showAddSlotButton: false,
                ),
                if (!_availabilityWindowValid(f)) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppFormHelperText(
                    f.availRangeStart == null || f.availRangeEnd == null
                        ? 'Select at least one day to apply this filter.'
                        : 'End time must be after start time across your selected dates.',
                  ),
                ],
              ],
            ],
          ),
        ),
        AppScreenSection(
          dividerAbove: true,
          title: 'Area',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Guelph listings only'),
            value: f.guelphOnly,
            onChanged: n.setGuelphOnly,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
