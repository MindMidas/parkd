import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/availability_overlap.dart';
import '../../../../../core/utils/time_step_minutes.dart';
import '../../../../../core/utils/weekday_ui_to_db.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../map/presentation/home_map_screen.dart';
import '../../../../map/presentation/main_tab.dart';
import '../../manage_listings/edit/confirmation_success_screen.dart';
import '../create_listing_draft.dart';
import 'set_pricing_screen.dart';
import 'terms_and_conditions_screen.dart';

enum _AvailabilityType { specific, weekly }

// Big availability step — pick weekly vs specific dates then slot editor
class SetAvailabilityScreen extends StatefulWidget {
  const SetAvailabilityScreen({
    super.key,
    required this.draft,
    this.onPublish,
    this.currentStep,
    this.totalSteps,
  });

  final CreateListingDraft draft;
  final VoidCallback? onPublish;

  final int? currentStep;
  final int? totalSteps;

  @override
  State<SetAvailabilityScreen> createState() => _SetAvailabilityScreenState();
}

class _SetAvailabilityScreenState extends State<SetAvailabilityScreen> {
  /// Until true, only the type picker is shown
  bool _typeChosen = false;

  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final Set<DateTime> _selectedDates = {};
  _AvailabilityType _availabilityType = _AvailabilityType.specific;

  // Specific slots — each has its own optional price
  final List<CreateListingSpecificSlot> _slots = [];

  // Weekly schedule: each row has its own optional daily + required hourly (on confirm)
  final Set<int> _weeklySelectedDays = {0, 1, 2, 3, 4, 5, 6};
  final List<CreateListingWeeklySlot> _weeklySlots = [];

  final DateTime _minDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  /// Minutes from midnight, 5-minute steps (see [TimeStepMinutes])
  int _startMinutes = 9 * 60 + 15;
  int _endMinutes = 15 * 60;

  String? _slotOverlapError;

  bool get _hasSlots => _availabilityType == _AvailabilityType.specific
      ? _slots.isNotEmpty
      : _weeklySlots.isNotEmpty;

  bool get _allSlotsPriced {
    if (_availabilityType == _AvailabilityType.specific) {
      return _slots.every((s) => s.hourlyPrice != null);
    }
    return _weeklySlots.every((s) => s.hourlyPrice != null);
  }

  bool get _hasValidListing => _hasSlots && _allSlotsPriced;

  void _onDayTap(DateTime date) {
    setState(() {
      final alreadySelected = _selectedDates.any(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      );
      if (alreadySelected) {
        _selectedDates.removeWhere(
          (d) =>
              d.year == date.year && d.month == date.month && d.day == date.day,
        );
      } else {
        _selectedDates.add(date);
      }
    });
  }

  void _addWeeklySlot(String startLabel, String endLabel) {
    final parsed = AvailabilityOverlap.tryParseAmPmTimeRange(
      '$startLabel - $endLabel',
    );
    if (parsed == null) return;

    final indices = _weeklySelectedDays.isEmpty
        ? <int>[0]
        : (_weeklySelectedDays.toList()..sort());
    final pendingSameAdd = <({int dayPg, int startMin, int endMin})>[];

    for (final dayIndex in indices) {
      final day = kWeekdayLabels[dayIndex];
      final dow = weekdayUiMonFirstToPostgres(dayIndex);

      for (final s in _weeklySlots) {
        if (s.day != day) continue;
        final ex = AvailabilityOverlap.tryParseAmPmTimeRange(s.timeRange);
        if (ex != null &&
            AvailabilityOverlap.intervalsOverlapHalfOpenMinutes(
              parsed.startMin,
              parsed.endMin,
              ex.startMin,
              ex.endMin,
            )) {
          setState(() {
            _slotOverlapError = AvailabilityOverlap.userMessageWeekly;
          });
          return;
        }
      }

      for (final t in pendingSameAdd) {
        if (t.dayPg != dow) continue;
        if (AvailabilityOverlap.intervalsOverlapHalfOpenMinutes(
          parsed.startMin,
          parsed.endMin,
          t.startMin,
          t.endMin,
        )) {
          setState(() {
            _slotOverlapError = AvailabilityOverlap.userMessageWeekly;
          });
          return;
        }
      }
      pendingSameAdd.add((
        dayPg: dow,
        startMin: parsed.startMin,
        endMin: parsed.endMin,
      ));
    }

    setState(() {
      _slotOverlapError = null;
      final timeRange = '$startLabel – $endLabel';
      for (final dayIndex in indices) {
        final day = kWeekdayLabels[dayIndex];
        final exists = _weeklySlots.any(
          (s) => s.day == day && s.timeRange == timeRange,
        );
        if (!exists) {
          _weeklySlots.add((
            day: day,
            timeRange: timeRange,
            hourlyPrice: null,
            dailyPrice: null,
          ));
        }
      }
    });
  }

  DateTime _dateAtMinutes(DateTime d, int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    return DateTime(d.year, d.month, d.day, h, m);
  }

  ({DateTime start, DateTime end}) _specificSlotBounds(
    CreateListingSpecificSlot s,
  ) {
    final a = TimeStepMinutes.tryParseMinutesFromAmPm(s.startTime);
    final b = TimeStepMinutes.tryParseMinutesFromAmPm(s.endTime);
    if (a == null || b == null) {
      return (start: s.fromDate, end: s.toDate);
    }
    return (
      start: _dateAtMinutes(s.fromDate, a),
      end: _dateAtMinutes(s.toDate, b),
    );
  }

  void _addSlot() {
    if (_selectedDates.isEmpty) return;
    final sorted = _selectedDates.toList()..sort();
    final fromDate = sorted.first;
    final toDate = sorted.last;
    final startDt = _dateAtMinutes(fromDate, _startMinutes);
    final endDt = _dateAtMinutes(toDate, _endMinutes);
    if (!endDt.isAfter(startDt)) {
      setState(() {
        _slotOverlapError =
            'End time must be after start time for this date range.';
      });
      return;
    }

    for (final s in _slots) {
      final e = _specificSlotBounds(s);
      if (AvailabilityOverlap.dateTimeRangesOverlap(
        startDt,
        endDt,
        e.start,
        e.end,
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
        fromDate: fromDate,
        toDate: toDate,
        startTime: TimeStepMinutes.formatAmPm(_startMinutes),
        endTime: TimeStepMinutes.formatAmPm(_endMinutes),
        hourlyPrice: null,
        dailyPrice: null,
      ));
      _selectedDates.clear();
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _slots.removeAt(index);
      _slotOverlapError = null;
    });
  }

  void _removeWeeklySlot(int index) {
    setState(() {
      _weeklySlots.removeAt(index);
      _slotOverlapError = null;
    });
  }

  void _selectAvailabilityType(_AvailabilityType type) {
    setState(() {
      _availabilityType = type;
      _typeChosen = true;
    });
  }

  void _clearAvailabilityDraft() {
    _slots.clear();
    _weeklySlots.clear();
    _selectedDates.clear();
  }

  /// From the form: back returns to the type picker and clears draft. From the
  /// picker: back leaves this screen (e.g. to annotate)
  void _handleBack() {
    if (_typeChosen) {
      setState(() {
        _clearAvailabilityDraft();
        _typeChosen = false;
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String _formatSlotDate(DateTime date, String time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $time';
  }

  // Open pricing screen for a specific slot
  Future<void> _openPricingForSlot(int index) async {
    final s = _slots[index];
    final result = await Navigator.push<({double hourly, double? daily})>(
      context,
      MaterialPageRoute(
        builder: (_) => SetPricingScreen(
          initialHourly: s.hourlyPrice,
          initialDaily: s.dailyPrice,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _slots[index] = (
          fromDate: s.fromDate,
          toDate: s.toDate,
          startTime: s.startTime,
          endTime: s.endTime,
          hourlyPrice: result.hourly,
          dailyPrice: result.daily,
        );
      });
    }
  }

  Future<void> _openPricingForWeeklySlot(int index) async {
    final s = _weeklySlots[index];
    final result = await Navigator.push<({double hourly, double? daily})>(
      context,
      MaterialPageRoute(
        builder: (_) => SetPricingScreen(
          initialHourly: s.hourlyPrice,
          initialDaily: s.dailyPrice,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _weeklySlots[index] = (
          day: s.day,
          timeRange: s.timeRange,
          hourlyPrice: result.hourly,
          dailyPrice: result.daily,
        );
      });
    }
  }

  bool _validateWeeklyDraftForConfirm() {
    final triples = <({int dayPg, int startMin, int endMin})>[];
    for (final s in _weeklySlots) {
      final i = kWeekdayLabels.indexOf(s.day);
      if (i < 0) continue;
      final d = weekdayUiMonFirstToPostgres(i);
      final p = AvailabilityOverlap.tryParseAmPmTimeRange(s.timeRange);
      if (p == null) continue;
      triples.add((dayPg: d, startMin: p.startMin, endMin: p.endMin));
    }
    if (AvailabilityOverlap.weeklyAnyPairOverlaps(triples)) {
      setState(() {
        _slotOverlapError = AvailabilityOverlap.userMessageWeekly;
      });
      return false;
    }
    setState(() => _slotOverlapError = null);
    return true;
  }

  bool _validateSpecificDraftForConfirm() {
    final ranges = <({DateTime start, DateTime end})>[];
    for (final s in _slots) {
      final b = _specificSlotBounds(s);
      ranges.add((start: b.start, end: b.end));
    }
    if (AvailabilityOverlap.specificListHasOverlap(ranges)) {
      setState(() {
        _slotOverlapError = AvailabilityOverlap.userMessageSpecific;
      });
      return false;
    }
    setState(() => _slotOverlapError = null);
    return true;
  }

  void _onConfirm() {
    if (!_hasValidListing) return;
    if (_availabilityType == _AvailabilityType.weekly) {
      if (!_validateWeeklyDraftForConfirm()) return;
    } else {
      if (!_validateSpecificDraftForConfirm()) return;
    }

    final d = widget.draft;
    d.availabilityKind = _availabilityType == _AvailabilityType.specific
        ? CreateListingAvailabilityKind.specific
        : CreateListingAvailabilityKind.weekly;
    d.specificSlots
      ..clear()
      ..addAll(_slots);
    d.weeklySlots
      ..clear()
      ..addAll(_weeklySlots);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TermsAndConditionsScreen(
          draft: d,
          currentStep: widget.currentStep != null
              ? widget.currentStep! + 1
              : null,
          totalSteps: widget.totalSteps,
          onPublishSuccess: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => ConfirmationSuccessScreen(
                  title: 'Listing Published',
                  message:
                      'Your parking spot is now live. Drivers can find and book it on Parkd.',
                  buttonLabel: 'Go to Home',
                  onClose: () {
                    if (widget.onPublish != null) {
                      widget.onPublish!();
                    } else {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const HomeMapScreen(
                            initialIndex: MainTab.map,
                            hasTabInRoute: true,
                          ),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  popsOnClose: 0,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTypePickerBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppSectionTitle(
            'When is this spot available?',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppFormHelperText(
            'Choose one. Only one schedule type applies per listing.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSelectableIconChevronCard(
            icon: Icons.event_note_rounded,
            title: 'Specific dates',
            subtitle:
                'Pick calendar days or ranges, then add time windows for each.',
            onTap: () => _selectAvailabilityType(_AvailabilityType.specific),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSelectableIconChevronCard(
            icon: Icons.date_range_rounded,
            title: 'Weekly schedule',
            subtitle:
                'Same hours on chosen days every week (e.g. Mon–Fri 9–5).',
            onTap: () => _selectAvailabilityType(_AvailabilityType.weekly),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildAvailabilityFormBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          if (_availabilityType == _AvailabilityType.specific) ...[
            AppListingSpecificDatesInputCard(
              title: 'Specific dates',
              calendar: AppMonthCalendar(
                currentMonth: _currentMonth,
                selectedDates: _selectedDates,
                minDate: _minDate,
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
                onDayTap: _onDayTap,
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
              addEnabled: _selectedDates.isNotEmpty,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppListingSpecificDateSlotsCard(
              title: 'Scheduled time slots',
              emptyLabel: 'No slots added yet',
              slots: _slots
                  .map(
                    (s) => (
                      from: _formatSlotDate(s.fromDate, s.startTime),
                      to: _formatSlotDate(s.toDate, s.endTime),
                      priceHour: s.hourlyPrice ?? 0,
                      priceDay: s.dailyPrice,
                    ),
                  )
                  .toList(),
              onRemove: _removeSlot,
              onTapSlot: _openPricingForSlot,
            ),
            if (_slotOverlapError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppFormErrorCaption(_slotOverlapError!),
            ],
          ] else ...[
            AppListingWeeklyScheduleInputCard(
              title: 'Weekly schedule',
              selectedDayIndices: _weeklySelectedDays,
              onDaysChanged: (v) => setState(() {
                _weeklySelectedDays.clear();
                _weeklySelectedDays.addAll(v);
              }),
              onAddSlot: _addWeeklySlot,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppListingWeeklyScheduledSlotsCard(
              title: 'Scheduled time slots',
              emptyLabel: 'No weekly slots added yet',
              slots: _weeklySlots
                  .map(
                    (s) => (
                      day: s.day,
                      timeRange: s.timeRange,
                      priceHour: s.hourlyPrice ?? 0,
                      priceDay: s.dailyPrice,
                    ),
                  )
                  .toList(),
              onRemove: _removeWeeklySlot,
              onTapSlot: _openPricingForWeeklySlot,
            ),
            if (_slotOverlapError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppFormErrorCaption(_slotOverlapError!),
            ],
          ],
          const SizedBox(height: AppSpacing.lg),
          if (_hasSlots && !_allSlotsPriced)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppFormHelperText(
                'Tap a slot to set its price',
                textAlign: TextAlign.center,
              ),
            ),
          AppPrimaryButton(
            label: 'Confirm',
            icon: Icons.check_rounded,
            onPressed: _hasValidListing ? _onConfirm : null,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useStepBar = widget.currentStep != null && widget.totalSteps != null;

    return PopScope(
      canPop: !_typeChosen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_typeChosen) {
          setState(() {
            _clearAvailabilityDraft();
            _typeChosen = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: useStepBar
            ? AppStepTopBar(
                title: 'Availability',
                currentStep: widget.currentStep!,
                totalSteps: widget.totalSteps!,
                onBack: _handleBack,
              )
            : AppTopBar(
                title: 'Availability',
                showBack: true,
                onBack: _handleBack,
              ),
        body: SafeArea(
          bottom: false,
          child: _typeChosen
              ? _buildAvailabilityFormBody()
              : _buildTypePickerBody(),
        ),
      ),
    );
  }
}
