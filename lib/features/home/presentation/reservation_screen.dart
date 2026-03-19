import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'confirm_pay_screen.dart';

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({
    super.key,
    required this.hourlyRate,
    required this.dailyRate,
    required this.availableWeekdays,
    required this.streetAddress,
    required this.cityLine,
    required this.latitude,
    required this.longitude,
  });

  final double hourlyRate;
  final double dailyRate;
  final String streetAddress;
  final String cityLine;
  final double latitude;
  final double longitude;

  /// Set of weekday numbers that are available (DateTime.monday == 1 .. DateTime.sunday == 7).
  final Set<int> availableWeekdays;

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);

  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  // -----------------------------------------------------------------------
  // Price calculation: $dailyRate per full day + $hourlyRate per extra hour
  // -----------------------------------------------------------------------
  String get _totalPrice {
    if (_startDate == null || _endDate == null) return '\$0.00';

    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) return '\$0.00';

    final diff = end.difference(start);
    final totalHours = diff.inMinutes / 60.0;
    final fullDays = diff.inDays;
    final remainingHours = (totalHours - fullDays * 24).ceil();

    final cost =
        fullDays * widget.dailyRate + remainingHours * widget.hourlyRate;

    return '\$${cost.toStringAsFixed(2)}';
  }

  String get _durationLabel {
    if (_startDate == null || _endDate == null) return '';

    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime.hour,
      _startTime.minute,
    );
    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (end.isBefore(start) || end.isAtSameMomentAs(start)) return '';

    final diff = end.difference(start);
    final fullDays = diff.inDays;
    final remainingHours =
        (diff.inMinutes / 60.0 - fullDays * 24).ceil();

    final parts = <String>[];
    if (fullDays > 0) parts.add('$fullDays day${fullDays == 1 ? '' : 's'}');
    if (remainingHours > 0) {
      parts.add('$remainingHours hour${remainingHours == 1 ? '' : 's'}');
    }
    return parts.join(' and ');
  }

  // -----------------------------------------------------------------------
  // Calendar helpers
  // -----------------------------------------------------------------------
  int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  int _firstWeekdayOffset(DateTime month) =>
      DateTime(month.year, month.month, 1).weekday; // Mon=1 .. Sun=7

  void _prevMonth() {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth =
          DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    });
  }

  bool _isAvailable(DateTime day) {
    return widget.availableWeekdays.contains(day.weekday);
  }

  void _onDayTapped(DateTime day) {
    if (!_isAvailable(day)) return;
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = day;
        _endDate = null;
      } else {
        if (day.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = day;
        } else {
          _endDate = day;
        }
      }
    });
  }

  bool _isInRange(DateTime day) {
    if (_startDate == null || _endDate == null) return false;
    return day.isAfter(_startDate!) && day.isBefore(_endDate!);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryBlue,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '---';
    return DateFormat('MMM d, y').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final now = DateTime(2000, 1, 1, time.hour, time.minute);
    return DateFormat('h:mm a').format(now);
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        DateFormat('MMM yyyy').format(_displayedMonth);
    final daysInMonth = _daysInMonth(_displayedMonth);
    final offset = _firstWeekdayOffset(_displayedMonth); // 1=Mon..7=Sun

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.primaryBlue,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Choose parking duration',
                      style: AppTypography.title.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // --- Scrollable content ---
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    // --- Set start and end dates label ---
                    Center(
                      child: Text(
                        'Set start and end dates',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // --- Calendar card ---
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.secondaryGrey.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          // Month nav
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                monthLabel,
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _prevMonth,
                                    child: const Icon(
                                      Icons.chevron_left,
                                      size: 22,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _nextMonth,
                                    child: const Icon(
                                      Icons.chevron_right,
                                      size: 22,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Weekday headers
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
                                .map(
                                  (d) => SizedBox(
                                    width: 36,
                                    child: Center(
                                      child: Text(
                                        d,
                                        style:
                                            AppTypography.caption.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          // Day grid
                          _buildDayGrid(daysInMonth, offset),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // --- Set start and end time label ---
                    Center(
                      child: Text(
                        'Set start and end time',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Divider(height: AppSpacing.lg),
                    // --- Start time ---
                    _buildTimeRow(
                      label: 'Start time',
                      value:
                          '${_formatDate(_startDate)} • ${_formatTime(_startTime)}',
                      onTap: () => _pickTime(isStart: true),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // --- End time ---
                    _buildTimeRow(
                      label: 'End time',
                      value:
                          '${_formatDate(_endDate)} • ${_formatTime(_endTime)}',
                      onTap: () => _pickTime(isStart: false),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // --- Reservation total ---
                    Center(
                      child: Text(
                        'Reservation total',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Divider(height: AppSpacing.lg),
                    Text(
                      '$_totalPrice for $_durationLabel',
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
            // --- Confirm button ---
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      (_startDate != null && _endDate != null)
                          ? () {
                              final start = DateTime(
                                _startDate!.year,
                                _startDate!.month,
                                _startDate!.day,
                                _startTime.hour,
                                _startTime.minute,
                              );
                              final end = DateTime(
                                _endDate!.year,
                                _endDate!.month,
                                _endDate!.day,
                                _endTime.hour,
                                _endTime.minute,
                              );
                              final diff = end.difference(start);
                              final fullDays = diff.inDays;
                              final remainingHours =
                                  (diff.inMinutes / 60.0 - fullDays * 24)
                                      .ceil();
                              final subtotal = fullDays * widget.dailyRate +
                                  remainingHours * widget.hourlyRate;

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ConfirmPayScreen(
                                    streetAddress: widget.streetAddress,
                                    cityLine: widget.cityLine,
                                    latitude: widget.latitude,
                                    longitude: widget.longitude,
                                    startDateTime: start,
                                    endDateTime: end,
                                    durationLabel: _durationLabel,
                                    subtotal: subtotal,
                                  ),
                                ),
                              );
                            }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Confirm',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Calendar grid
  // -----------------------------------------------------------------------
  Widget _buildDayGrid(int daysInMonth, int firstWeekday) {
    // firstWeekday: Mon=1..Sun=7  →  blanks before day 1 = firstWeekday - 1
    final blanks = firstWeekday - 1;
    final totalCells = blanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (col) {
              final index = row * 7 + col;
              if (index < blanks || index >= blanks + daysInMonth) {
                return const SizedBox(width: 36, height: 36);
              }
              final day = index - blanks + 1;
              final date = DateTime(
                _displayedMonth.year,
                _displayedMonth.month,
                day,
              );

              final available = _isAvailable(date);
              final isStart =
                  _startDate != null && _isSameDay(date, _startDate!);
              final isEnd =
                  _endDate != null && _isSameDay(date, _endDate!);
              final inRange = _isInRange(date);

              Color bgColor = Colors.transparent;
              Color textColor = available
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.35);

              if (available) {
                if (isStart) {
                  bgColor =
                      AppColors.textSecondary.withValues(alpha: 0.3);
                  textColor = AppColors.textPrimary;
                } else if (isEnd) {
                  bgColor = AppColors.primaryBlue;
                  textColor = Colors.white;
                } else if (inRange) {
                  bgColor =
                      AppColors.primaryBlue.withValues(alpha: 0.1);
                }
              }

              return GestureDetector(
                onTap: () => _onDayTapped(date),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: AppTypography.body.copyWith(
                      color: textColor,
                      fontWeight:
                          (isStart || isEnd) ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  // -----------------------------------------------------------------------
  // Time row
  // -----------------------------------------------------------------------
  Widget _buildTimeRow({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(value, style: AppTypography.body),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}
