import 'package:flutter/material.dart';

import '../../../../../core/models/availability_specific.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/availability_overlap.dart';
import '../../../../../core/utils/time_step_minutes.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../create_listing/create_listing_flow/set_pricing_screen.dart';
import 'confirmation_success_screen.dart';

typedef _DateSlotDraft = ({
  DateTime start,
  DateTime end,
  double? hourlyPrice,
  double? dailyPrice,
});

// Edit specific-date slots for a listing you already own
class SetAvailabilityDatesScreen extends StatefulWidget {
  const SetAvailabilityDatesScreen({
    super.key,
    required this.listingId,
    this.currentStep,
    this.totalSteps,
  });

  final String listingId;
  final int? currentStep;
  final int? totalSteps;

  @override
  State<SetAvailabilityDatesScreen> createState() =>
      _SetAvailabilityDatesScreenState();
}

class _SetAvailabilityDatesScreenState
    extends State<SetAvailabilityDatesScreen> {
  late DateTime _currentMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  static DateTime get _today =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  int _startMinutes = 9 * 60 + 15;
  int _endMinutes = 15 * 60;
  final List<_DateSlotDraft> _slots = [];

  String? _slotOverlapError;

  bool get _hasSlots => _slots.isNotEmpty;

  bool get _allSlotsPriced => _slots.every((s) => (s.hourlyPrice ?? 0) > 0);

  bool get _canConfirm => !_hasSlots || _allSlotsPriced;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  // All dates in the selected range for calendar highlighting (start through end inclusive)
  Set<DateTime> get _selectedDatesForCalendar {
    if (_rangeStart == null || _rangeEnd == null) {
      if (_rangeStart != null) {
        return {
          DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day),
        };
      }
      return {};
    }
    final start = _rangeStart!.isBefore(_rangeEnd!) ? _rangeStart! : _rangeEnd!;
    final end = _rangeStart!.isAfter(_rangeEnd!) ? _rangeStart! : _rangeEnd!;
    final set = <DateTime>{};
    var d = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    while (!d.isAfter(endDate)) {
      set.add(d);
      d = d.add(const Duration(days: 1));
    }
    return set;
  }

  static void _noopClose() {}

  Future<void> _openPricingForSlot(int index) async {
    final s = _slots[index];
    final result = await Navigator.push<({double hourly, double? daily})>(
      context,
      AppPageRoute<({double hourly, double? daily})>(
        builder: (_) => SetPricingScreen(
          initialHourly: s.hourlyPrice ?? 10,
          initialDaily: s.dailyPrice,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _slots[index] = (
        start: s.start,
        end: s.end,
        hourlyPrice: result.hourly,
        dailyPrice: result.daily,
      );
    });
  }

  void _onConfirm() {
    final ranges = _slots.map((s) => (start: s.start, end: s.end)).toList();
    if (AvailabilityOverlap.specificListHasOverlap(ranges)) {
      setState(() {
        _slotOverlapError = AvailabilityOverlap.userMessageSpecific;
      });
      return;
    }

    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ConfirmationSuccessScreen(
          message: 'Availability updated',
          onClose: _noopClose,
          popsOnClose: 2,
        ),
      ),
    );
  }

  void _addSlot() {
    DateTime? start = _rangeStart != null
        ? DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day)
        : null;
    DateTime? end = _rangeEnd != null
        ? DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day)
        : null;
    if (start == null || end == null) return;
    if (start.isAfter(end)) {
      final t = start;
      start = end;
      end = t;
    }

    final startDt = DateTime(
      start.year,
      start.month,
      start.day,
      _startMinutes ~/ 60,
      _startMinutes % 60,
    );
    final endDt = DateTime(
      end.year,
      end.month,
      end.day,
      _endMinutes ~/ 60,
      _endMinutes % 60,
    );

    if (!endDt.isAfter(startDt)) {
      setState(() {
        _slotOverlapError =
            'End time must be after start time for this date range.';
      });
      return;
    }

    for (final s in _slots) {
      if (AvailabilityOverlap.dateTimeRangesOverlap(
        startDt,
        endDt,
        s.start,
        s.end,
      )) {
        setState(() {
          _slotOverlapError = AvailabilityOverlap.userMessageSpecific;
        });
        return;
      }
    }

    setState(() {
      _slotOverlapError = null;
      _slots.add((
        start: startDt,
        end: endDt,
        hourlyPrice: null,
        dailyPrice: null,
      ));
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
      _slotOverlapError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardSlots = _slots
        .map(
          (s) => (
            from: AvailabilitySpecific.formatDateTime(s.start),
            to: AvailabilitySpecific.formatDateTime(s.end),
            priceHour: s.hourlyPrice ?? 0,
            priceDay: s.dailyPrice,
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Availability', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    AppListingSpecificDatesInputCard(
                      title: 'Specific dates',
                      calendar: AppMonthCalendar(
                        currentMonth: _currentMonth,
                        selectedDates: _selectedDatesForCalendar,
                        minDate: _today,
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
                        onDayTap: (date) {
                          setState(() {
                            final dayOnly = DateTime(
                              date.year,
                              date.month,
                              date.day,
                            );
                            if (_rangeStart == null) {
                              _rangeStart = dayOnly;
                              _rangeEnd = dayOnly;
                            } else if (_rangeStart == _rangeEnd) {
                              if (dayOnly.isBefore(_rangeStart!)) {
                                _rangeStart = dayOnly;
                              } else {
                                _rangeEnd = dayOnly;
                              }
                            } else {
                              _rangeStart = dayOnly;
                              _rangeEnd = dayOnly;
                            }
                          });
                        },
                      ),
                      startValue: TimeStepMinutes.formatAmPm(_startMinutes),
                      endValue: TimeStepMinutes.formatAmPm(_endMinutes),
                      onStartTap: () async {
                        final m = await showAppTimePickerMinutes(
                          context: context,
                          initialMinutes: _startMinutes,
                        );
                        if (m != null && mounted) {
                          setState(() => _startMinutes = m);
                        }
                      },
                      onEndTap: () async {
                        final m = await showAppTimePickerMinutes(
                          context: context,
                          initialMinutes: _endMinutes,
                        );
                        if (m != null && mounted) {
                          setState(() => _endMinutes = m);
                        }
                      },
                      onAddSlot: _addSlot,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppListingSpecificDateSlotsCard(
                      slots: cardSlots,
                      onRemove: _removeSlot,
                      onTapSlot: _openPricingForSlot,
                    ),
                    if (_slotOverlapError != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppFormErrorCaption(_slotOverlapError!),
                    ],
                    if (_hasSlots) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const AppFormHelperText(
                        'Tap a slot to set its price',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const AppAnnotatePhotoInstruction(
                      text:
                          'Changes will only apply to future reservations. '
                          'Existing or ongoing bookings will not be affected.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            AppStickyFooter(
              child: AppPrimaryButton(
                label: 'Confirm',
                onPressed: _canConfirm ? _onConfirm : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
