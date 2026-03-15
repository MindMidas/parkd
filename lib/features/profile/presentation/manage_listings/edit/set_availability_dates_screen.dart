import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/widgets.dart';
import 'confirmation_success_screen.dart';

/// Set availability using specific dates: calendar, start/end date time, add slots, list with remove, confirm.
class SetAvailabilityDatesScreen extends StatefulWidget {
  const SetAvailabilityDatesScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<SetAvailabilityDatesScreen> createState() =>
      _SetAvailabilityDatesScreenState();
}

class _SetAvailabilityDatesScreenState extends State<SetAvailabilityDatesScreen> {
  late DateTime _currentMonth;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  static DateTime get _today => DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  String _startDateTime = '9:15 AM';
  String _endDateTime = '3:00 PM';
  final List<({String from, String to})> _slots = [
    (from: 'Sep 15, 2026 • 9:00 AM', to: 'Sep 20, 2026 • 3:00 PM'),
    (from: 'Oct 3, 2026 • 10:00 AM', to: 'Oct 7, 2026 • 6:00 PM'),
  ];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  /// All dates in the selected range for calendar highlighting (start through end inclusive).
  Set<DateTime> get _selectedDatesForCalendar {
    if (_rangeStart == null || _rangeEnd == null) {
      if (_rangeStart != null) return {DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day)};
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

  void _onConfirm() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmationSuccessScreen(
          message: 'Availability updated',
          onClose: _noopClose,
          popsOnClose: 3,
        ),
      ),
    );
  }

  void _addSlot() {
    setState(() {
      DateTime? start = _rangeStart != null ? DateTime(_rangeStart!.year, _rangeStart!.month, _rangeStart!.day) : null;
      DateTime? end = _rangeEnd != null ? DateTime(_rangeEnd!.year, _rangeEnd!.month, _rangeEnd!.day) : null;
      if (start != null && end != null && start.isAfter(end)) {
        final t = start;
        start = end;
        end = t;
      }
      final from = start != null
          ? '${_formatDate(start)} • $_startDateTime'
          : 'Sep 15, 2026 • 9:00 AM';
      final to = end != null
          ? '${_formatDate(end)} • $_endDateTime'
          : 'Sep 20, 2026 • 3:00 PM';
      _slots.add((from: from, to: to));
    });
  }

  void _removeSlot(int index) {
    setState(() => _slots.removeAt(index));
  }

  static String _formatDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Set your specific dates',
        showBack: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Choose when the parking spot is available.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppMonthCalendar(
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
                          final dayOnly = DateTime(date.year, date.month, date.day);
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
                    const SizedBox(height: AppSpacing.lg),
                    AppTimeStepperRow(
                      label: 'Start date time',
                      value: _startDateTime,
                      labelWidth: 120,
                      onDecrement: () => setState(() => _startDateTime = '9:00 AM'),
                      onIncrement: () => setState(() => _startDateTime = '9:30 AM'),
                    ),
                    AppTimeStepperRow(
                      label: 'End date time',
                      value: _endDateTime,
                      labelWidth: 120,
                      onDecrement: () => setState(() => _endDateTime = '2:30 PM'),
                      onIncrement: () => setState(() => _endDateTime = '3:30 PM'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppPrimaryButton(label: 'Add slot', onPressed: _addSlot),
                    const AppSectionDividerTitle('Scheduled time slots'),
                    ...List.generate(_slots.length, (i) {
                      final s = _slots[i];
                      return AppSlotCardRemove(
                        onRemove: () => _removeSlot(i),
                        child: AppSlotCardRemoveDateRange(
                          from: s.from,
                          to: s.to,
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.lg),
                    AppPrimaryButton(label: 'Confirm', onPressed: _onConfirm),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
