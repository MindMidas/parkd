import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Mon–Sun short labels (weekly UI)
const List<String> kWeekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

// Day chips: row of 4 then 3; selectedIndices 0 = Mon … 6 = Sun
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

  static const double _chipWidth = 64;
  static const double _chipHeight = 40;
  static const double _circleSize = 18;
  static const double _iconSize = 11;
  static const double _labelFontSize = 11;

  @override
  Widget build(BuildContext context) {
    Widget chip(int index) {
      final selected = selectedIndices.contains(index);
      return _DayChip(
        label: labels[index],
        selected: selected,
        onTap: () {
          final next = Set<int>.from(selectedIndices);
          if (selected) {
            next.remove(index);
          } else {
            next.add(index);
          }
          onChanged(next);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Available Days', style: AppTypography.bodyStrong),
        const SizedBox(height: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 4; i++) ...[
                  if (i > 0) SizedBox(width: AppSpacing.sm),
                  chip(i),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) SizedBox(width: AppSpacing.sm),
                  chip(i + 4),
                ],
              ],
            ),
          ],
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
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: AppDayCheckboxes._chipWidth,
          height: AppDayCheckboxes._chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.secondaryBlue : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.secondaryGrey.withValues(alpha: 0.6),
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
                      : AppColors.secondaryGrey.withValues(alpha: 0.3),
                ),
                child: Icon(
                  selected ? Icons.check : Icons.close,
                  size: AppDayCheckboxes._iconSize,
                  color: selected
                      ? AppColors.onPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySecondary.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: AppDayCheckboxes._labelFontSize,
                    height: 1.1,
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
