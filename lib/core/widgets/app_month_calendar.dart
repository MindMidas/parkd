import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Simple month calendar: month/year label, prev/next for month and year, grid of days. Supports range selection (all dates in [selectedDates] highlighted; latest = primary/blue).
/// Pass [minDate] (e.g. today) to disable going before that date and to grey out past days.
class AppMonthCalendar extends StatelessWidget {
  const AppMonthCalendar({
    super.key,
    required this.currentMonth,
    required this.selectedDates,
    required this.onPrevMonth,
    required this.onNextMonth,
    this.onPrevYear,
    this.onNextYear,
    this.minDate,
    this.onDayTap,
  });

  final DateTime currentMonth;
  final Set<DateTime> selectedDates;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback? onPrevYear;
  final VoidCallback? onNextYear;
  /// No navigation before this date; days before this are disabled. Typically DateTime.now() normalized to midnight.
  final DateTime? minDate;
  final ValueChanged<DateTime>? onDayTap;

  static const _weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  @override
  Widget build(BuildContext context) {
    final year = currentMonth.year;
    final month = currentMonth.month;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = first.weekday - 1; // MO=0
    final leadingEmpty = startWeekday;
    final gridCount = leadingEmpty + daysInMonth;
    final monthLabel = _monthLabel(month, year);
    final minDay = minDate != null ? DateTime(minDate!.year, minDate!.month, minDate!.day) : null;
    final canGoPrevMonth = minDay == null ||
        (year > minDay.year || (year == minDay.year && month > minDay.month));
    final canGoPrevYear = minDay == null || year > minDay.year;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondaryGrey.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthLabel,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onPrevYear != null)
                    IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      onPressed: canGoPrevYear ? onPrevYear : null,
                      color: canGoPrevYear ? AppColors.primaryBlue : AppColors.textSecondary,
                      tooltip: 'Previous year',
                    ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: canGoPrevMonth ? onPrevMonth : null,
                    color: canGoPrevMonth ? AppColors.primaryBlue : AppColors.textSecondary,
                    tooltip: 'Previous month',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: onNextMonth,
                    color: AppColors.primaryBlue,
                    tooltip: 'Next month',
                  ),
                  if (onNextYear != null)
                    IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_right),
                      onPressed: onNextYear,
                      color: AppColors.primaryBlue,
                      tooltip: 'Next year',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekdays
                .map((d) => SizedBox(
                      width: 36,
                      child: Center(
                        child: Text(
                          d,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xs),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1.2,
            children: List.generate(gridCount, (i) {
              if (i < leadingEmpty) return const SizedBox.shrink();
              final day = i - leadingEmpty + 1;
              final date = DateTime(year, month, day);
              final selected = selectedDates.any(
                (d) => d.year == date.year && d.month == date.month && d.day == date.day,
              );
              DateTime? latest;
              for (final d in selectedDates) {
                if (latest == null || d.isAfter(latest)) latest = d;
              }
              final isPrimary = selected &&
                  latest != null &&
                  date.year == latest.year &&
                  date.month == latest.month &&
                  date.day == latest.day;
              final isPast = minDay != null && date.isBefore(minDay);
              return GestureDetector(
                onTap: isPast ? null : () => onDayTap?.call(date),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? (isPrimary
                            ? AppColors.primaryBlue
                            : AppColors.secondaryGrey.withValues(alpha: 0.4))
                        : null,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$day',
                    style: AppTypography.caption.copyWith(
                      color: isPast
                          ? AppColors.textSecondary.withValues(alpha: 0.5)
                          : (selected && isPrimary
                              ? Colors.white
                              : AppColors.textPrimary),
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  static String _monthLabel(int month, int year) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${names[month - 1]} $year';
  }
}
