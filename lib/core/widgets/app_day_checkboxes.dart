import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Day abbreviations for weekly schedule (Mon–Sun).
const List<String> kWeekdayLabels = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];

/// Reusable "Available Days" row. Fixed-size chips, centered; checkmark when selected, X when not. [selectedIndices] 0 = Mon … 6 = Sun.
class AppDayCheckboxes extends StatelessWidget {
  const AppDayCheckboxes({
    super.key,
    required this.selectedIndices,
    required this.onChanged,
    this.labels = kWeekdayLabels,
  });

  final Set<int> selectedIndices;
  final ValueChanged<Set<int>> onChanged;
  final List<String> labels;

  static const double _chipWidth = 72;
  static const double _chipHeight = 44;
  static const double _circleSize = 22;
  static const double _labelFontSize = 13;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Days',
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.start,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: List.generate(7, (i) {
            final selected = selectedIndices.contains(i);
            return _DayChip(
              label: labels[i],
              selected: selected,
              onTap: () {
                final next = Set<int>.from(selectedIndices);
                if (selected) {
                  next.remove(i);
                } else {
                  next.add(i);
                }
                onChanged(next);
              },
            );
          }),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: AppDayCheckboxes._chipWidth,
          height: AppDayCheckboxes._chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.secondaryBlue
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.secondaryGrey.withOpacity(0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: AppDayCheckboxes._circleSize,
                height: AppDayCheckboxes._circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primaryBlue
                      : AppColors.secondaryGrey.withOpacity(0.3),
                ),
                child: Icon(
                  selected ? Icons.check : Icons.close,
                  size: 14,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: AppDayCheckboxes._labelFontSize,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
