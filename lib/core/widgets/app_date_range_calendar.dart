import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A calendar with date-range selection and optional day-level availability.
///
/// Calls [onRangeChanged] whenever the start or end date changes.
/// Pass [availableWeekdays] to grey-out and disable tapping on unavailable days.
class AppDateRangeCalendar extends StatefulWidget {
  const AppDateRangeCalendar({
    super.key,
    this.startDate,
    this.endDate,
    this.availableWeekdays,
    required this.onRangeChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;

  /// Weekday numbers (DateTime.monday == 1 .. DateTime.sunday == 7) that are
  /// selectable. If null every day is selectable.
  final Set<int>? availableWeekdays;

  /// Called with (startDate, endDate) whenever the selection changes.
  final void Function(DateTime? start, DateTime? end) onRangeChanged;

  @override
  State<AppDateRangeCalendar> createState() => _AppDateRangeCalendarState();
}

class _AppDateRangeCalendarState extends State<AppDateRangeCalendar> {
  late DateTime _displayedMonth;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _start = widget.startDate;
    _end = widget.endDate;
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;
  int _firstWeekdayOffset(DateTime m) => DateTime(m.year, m.month, 1).weekday;

  bool _isAvailable(DateTime day) {
    if (widget.availableWeekdays == null) return true;
    return widget.availableWeekdays!.contains(day.weekday);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isInRange(DateTime day) {
    if (_start == null || _end == null) return false;
    return day.isAfter(_start!) && day.isBefore(_end!);
  }

  void _onDayTapped(DateTime day) {
    if (!_isAvailable(day)) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        _start = day;
        _end = null;
      } else {
        if (day.isBefore(_start!)) {
          _end = _start;
          _start = day;
        } else {
          _end = day;
        }
      }
    });
    widget.onRangeChanged(_start, _end);
  }

  void _prevMonth() => setState(() {
        _displayedMonth =
            DateTime(_displayedMonth.year, _displayedMonth.month - 1);
      });

  void _nextMonth() => setState(() {
        _displayedMonth =
            DateTime(_displayedMonth.year, _displayedMonth.month + 1);
      });

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMM yyyy').format(_displayedMonth);
    final daysInMonth = _daysInMonth(_displayedMonth);
    final offset = _firstWeekdayOffset(_displayedMonth);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.secondaryGrey.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          // Month nav
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
                .map(
                  (d) => SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(
                        d,
                        style: AppTypography.caption.copyWith(
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
    );
  }

  Widget _buildDayGrid(int daysInMonth, int firstWeekday) {
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
              final isStart = _start != null && _isSameDay(date, _start!);
              final isEnd = _end != null && _isSameDay(date, _end!);
              final inRange = _isInRange(date);

              Color bgColor = Colors.transparent;
              Color textColor = available
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.35);

              if (available) {
                if (isStart) {
                  bgColor = AppColors.textSecondary.withValues(alpha: 0.3);
                  textColor = AppColors.textPrimary;
                } else if (isEnd) {
                  bgColor = AppColors.primaryBlue;
                  textColor = Colors.white;
                } else if (inRange) {
                  bgColor = AppColors.primaryBlue.withValues(alpha: 0.1);
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
                      fontWeight: (isStart || isEnd) ? FontWeight.w600 : null,
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
}
