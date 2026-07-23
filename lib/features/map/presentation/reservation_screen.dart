import 'package:flutter/material.dart';

import '../../../core/map/availability_heatmap_logic.dart';
import '../../../core/models/availability_specific.dart';
import '../../../core/models/availability_weekly.dart';
import '../../../core/models/booking_time_window.dart';
import '../../../core/models/listing.dart';
import '../../../core/utils/reservation_pricing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/time_step_minutes.dart';
import '../../../core/widgets/widgets.dart';
import 'confirm_pay_screen.dart';

// Pick times on the heatmap then move toward checkout
class ReservationScreen extends StatefulWidget {
  const ReservationScreen({
    super.key,
    required this.listing,
    required this.weekly,
    required this.specific,
    required this.bookings,
    required this.hourlyRate,
    required this.dailyRate,
    required this.availableWeekdays,
    required this.streetAddress,
    required this.localityLine,
    this.spotLabel,
    required this.latitude,
    required this.longitude,
    this.heatmapLoading = false,
  });

  final Listing listing;
  final List<AvailabilityWeekly> weekly;
  final List<AvailabilitySpecific> specific;
  final List<BookingTimeWindow> bookings;

  final double hourlyRate;
  final double dailyRate;
  final String streetAddress;
  final String localityLine;
  final String? spotLabel;
  final double latitude;
  final double longitude;

  final Set<int> availableWeekdays;

  final bool heatmapLoading;

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  late DateTime _currentMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  int _startMinutes = 9 * 60;
  int _endMinutes = 15 * 60;

  DateTime get _today =>
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool _isSameCalendarDayAsToday(DateTime day) =>
      day.year == _today.year &&
      day.month == _today.month &&
      day.day == _today.day;

  /// Slot start on [dayOnly] must be strictly after "now" to be bookable
  bool _minuteSlotStillBookable(DateTime dayOnly, int minutesFromMidnight) {
    final slotStart = DateTime(
      dayOnly.year,
      dayOnly.month,
      dayOnly.day,
      minutesFromMidnight ~/ 60,
      minutesFromMidnight % 60,
    );
    return slotStart.isAfter(DateTime.now());
  }

  List<int> _filterPastMinutesForDay(DateTime dayOnly, List<int> minutes) {
    if (!_isSameCalendarDayAsToday(dayOnly)) return minutes;
    return minutes.where((m) => _minuteSlotStillBookable(dayOnly, m)).toList();
  }

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

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

  bool _isDateSelectable(DateTime date) {
    final dayOnly = DateTime(date.year, date.month, date.day);
    if (dayOnly.isBefore(_today)) return false;

    final host = hostOpenIntervalsForDay(
      dayOnly,
      widget.listing,
      widget.weekly,
      widget.specific,
    );
    if (host.isNotEmpty) {
      final slots = computeFiveMinuteSlotStates(
        dayLocal: dayOnly,
        listing: widget.listing,
        weekly: widget.weekly,
        specific: widget.specific,
        bookings: widget.bookings,
      );
      if (!slots.any((s) => s == AvailabilitySlotState.open)) return false;
    } else if (!widget.availableWeekdays.contains(dayOnly.weekday)) {
      return false;
    }

    if (_isSameCalendarDayAsToday(dayOnly) &&
        _openMinutesForDay(date).isEmpty) {
      return false;
    }
    return true;
  }

  List<int> _openMinutesForDay(DateTime day) {
    final dayOnly = DateTime(day.year, day.month, day.day);
    final host = hostOpenIntervalsForDay(
      dayOnly,
      widget.listing,
      widget.weekly,
      widget.specific,
    );
    final slots = computeFiveMinuteSlotStates(
      dayLocal: dayOnly,
      listing: widget.listing,
      weekly: widget.weekly,
      specific: widget.specific,
      bookings: widget.bookings,
    );
    final out = <int>[];
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] == AvailabilitySlotState.open) {
        out.add(i * TimeStepMinutes.step);
      }
    }
    if (out.isNotEmpty) return _filterPastMinutesForDay(dayOnly, out);

    if (host.isEmpty && widget.availableWeekdays.contains(dayOnly.weekday)) {
      final full = List.generate(
        (TimeStepMinutes.maxMinutes ~/ TimeStepMinutes.step) + 1,
        (i) => i * TimeStepMinutes.step,
      );
      return _filterPastMinutesForDay(dayOnly, full);
    }
    return [];
  }

  DateTime get _startDateTime {
    if (_rangeStart == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime(
      _rangeStart!.year,
      _rangeStart!.month,
      _rangeStart!.day,
      _startMinutes ~/ 60,
      _startMinutes % 60,
    );
  }

  DateTime get _endDateTime {
    if (_rangeEnd == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime(
      _rangeEnd!.year,
      _rangeEnd!.month,
      _rangeEnd!.day,
      _endMinutes ~/ 60,
      _endMinutes % 60,
    );
  }

  double get _subtotalAmount {
    if (_rangeStart == null || _rangeEnd == null) return 0;
    final start = _startDateTime;
    final end = _endDateTime;
    if (!end.isAfter(start)) return 0;
    final minutes = end.difference(start).inMinutes;
    return ReservationPricing.computeSubtotal(
      rawMinutes: minutes,
      hourlyRate: widget.hourlyRate,
      dailyRate: widget.dailyRate,
    );
  }

  String get _durationLabel {
    if (_rangeStart == null || _rangeEnd == null) return '';
    final start = _startDateTime;
    final end = _endDateTime;
    if (!end.isAfter(start)) return '';
    return ReservationPricing.formatDurationLabel(
      end.difference(start).inMinutes,
    );
  }

  bool get _canConfirm {
    if (_rangeStart == null || _rangeEnd == null) return false;
    if (!_endDateTime.isAfter(_startDateTime)) return false;
    final mins = _endDateTime.difference(_startDateTime).inMinutes;
    if (mins < ReservationPricing.minBillableMinutes) return false;
    if (_subtotalAmount <= 0) return false;
    if (!_everyCalendarDayInRangeIsSelectable()) return false;
    final startAllowed = _openMinutesForDay(_rangeStart!);
    final endAllowed = _openMinutesForDay(_rangeEnd!);
    if (!startAllowed.contains(_startMinutes) ||
        !endAllowed.contains(_endMinutes)) {
      return false;
    }
    final now = DateTime.now();
    if (!_startDateTime.isAfter(now)) return false;
    if (!_endDateTime.isAfter(now)) return false;
    return true;
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Latest day `<= desiredEnd` such that every calendar day from [rangeStart]
  /// through that day is selectable (no gaps through unavailable / booked days)
  DateTime _lastContiguousSelectableEnd(
    DateTime rangeStart,
    DateTime desiredEnd,
  ) {
    var lo = rangeStart;
    var hi = desiredEnd;
    if (lo.isAfter(hi)) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    var d = lo;
    var lastGood = lo;
    while (!d.isAfter(hi)) {
      if (!_isDateSelectable(d)) {
        return lastGood;
      }
      lastGood = d;
      d = d.add(const Duration(days: 1));
    }
    return lastGood;
  }

  bool _everyCalendarDayInRangeIsSelectable() {
    if (_rangeStart == null || _rangeEnd == null) return false;
    var lo = DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day);
    var hi = DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day);
    if (lo.isAfter(hi)) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    var d = lo;
    while (!d.isAfter(hi)) {
      if (!_isDateSelectable(d)) return false;
      d = d.add(const Duration(days: 1));
    }
    return true;
  }

  void _onDayTap(DateTime date) {
    final tap = DateTime(date.year, date.month, date.day);
    if (!_isDateSelectable(tap)) return;

    setState(() {
      late DateTime ns;
      late DateTime ne;

      final had = _rangeStart != null && _rangeEnd != null;
      final collapsed = had && _sameCalendarDay(_rangeStart!, _rangeEnd!);

      if (!had) {
        ns = ne = tap;
      } else if (collapsed) {
        final anchor = _rangeStart!;
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

      ne = _lastContiguousSelectableEnd(ns, ne);
      _rangeStart = ns;
      _rangeEnd = ne;
      _clampTimesToAllowed();
    });
  }

  static int _nearestAllowedMinute(List<int> allowed, int target) {
    var best = allowed.first;
    var bestD = (allowed.first - target).abs();
    for (final m in allowed) {
      final d = (m - target).abs();
      if (d < bestD) {
        bestD = d;
        best = m;
      }
    }
    return best;
  }

  void _clampTimesToAllowed() {
    if (_rangeStart != null) {
      final a = _openMinutesForDay(_rangeStart!);
      if (a.isNotEmpty) {
        _startMinutes = _nearestAllowedMinute(a, _startMinutes);
      }
    }
    if (_rangeEnd != null) {
      final a = _openMinutesForDay(_rangeEnd!);
      if (a.isNotEmpty) {
        _endMinutes = _nearestAllowedMinute(a, _endMinutes);
      }
    }
    _reconcileStartEndAfterClamp();
  }

  /// After clamping to host grid, ensure end is after start when start/end share a calendar day
  void _reconcileStartEndAfterClamp() {
    if (_rangeStart == null || _rangeEnd == null) return;
    if (!_sameCalendarDay(_rangeStart!, _rangeEnd!)) return;

    final startAllowed = _openMinutesForDay(_rangeStart!);
    final endAllowed = _openMinutesForDay(_rangeEnd!);
    if (startAllowed.isEmpty || endAllowed.isEmpty) return;

    if (_endMinutes > _startMinutes) return;

    for (final m in endAllowed) {
      if (m > _startMinutes) {
        _endMinutes = m;
        return;
      }
    }
    for (final m in startAllowed.reversed) {
      if (m < _endMinutes) {
        _startMinutes = m;
        return;
      }
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final date = isStart ? _rangeStart : _rangeEnd;
    if (date == null) return;
    final allowed = _openMinutesForDay(date);
    if (allowed.isEmpty) return;
    final initial = isStart ? _startMinutes : _endMinutes;
    final picked = await showAppTimePickerAllowedMinutes(
      context: context,
      initialMinutes: initial,
      allowedMinutes: allowed,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startMinutes = picked;
        } else {
          _endMinutes = picked;
        }
        _reconcileStartEndAfterClamp();
      });
    }
  }

  void _onConfirm() {
    if (!_canConfirm) return;
    final start = _startDateTime;
    final end = _endDateTime;
    final minutes = end.difference(start).inMinutes;
    final subtotal = ReservationPricing.computeSubtotal(
      rawMinutes: minutes,
      hourlyRate: widget.hourlyRate,
      dailyRate: widget.dailyRate,
    );
    final serviceFee = ReservationPricing.serviceFeeForSubtotal(subtotal);

    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => ConfirmPayScreen(
          listingId: widget.listing.id,
          streetAddress: widget.streetAddress,
          localityLine: widget.localityLine,
          spotLabel: widget.spotLabel,
          latitude: widget.latitude,
          longitude: widget.longitude,
          startDateTime: start,
          endDateTime: end,
          durationLabel: _durationLabel,
          subtotal: subtotal,
          serviceFee: serviceFee,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Choose parking duration', showBack: true),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    AppDisplayTitledOutlineCard(
                      title: 'Availability',
                      child: AppListingAvailabilityHeatmap(
                        loading: widget.heatmapLoading,
                        listing: widget.listing,
                        weekly: widget.weekly,
                        specific: widget.specific,
                        bookings: widget.bookings,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppListingSpecificDatesInputCard(
                      title: 'Dates & times',
                      calendar: AppMonthCalendar(
                        currentMonth: _currentMonth,
                        selectedDates: _selectedDatesForCalendar,
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
                        onDayTap: _onDayTap,
                      ),
                      startValue: TimeStepMinutes.formatAmPm(_startMinutes),
                      endValue: TimeStepMinutes.formatAmPm(_endMinutes),
                      onStartTap: () => _pickTime(isStart: true),
                      onEndTap: () => _pickTime(isStart: false),
                      showAddSlotButton: false,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppDisplayTitledOutlineCard(
                      title: 'Total',
                      child: AppReservationTotalLine(
                        priceText: formatUsdAmount(_subtotalAmount),
                        durationLabel: _durationLabel,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            AppStickyFooter(
              child: AppPrimaryButton(
                label: 'Confirm',
                icon: Icons.check_rounded,
                onPressed: _canConfirm ? _onConfirm : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
