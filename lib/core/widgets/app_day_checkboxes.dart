import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';

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

// Day pills: row of 4 then 3; selectedIndices 0 = Mon … 6 = Sun
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

  static const double _chipHeight = 40;

  @override
  Widget build(BuildContext context) {
    Widget chip(int index) {
      final selected = selectedIndices.contains(index);
      return _DayPill(
        label: labels[index],
        selected: selected,
        onTap: () {
          AppFeedback.selection(context);
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (int i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(child: chip(i)),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.xs),
                  Expanded(child: chip(i + 4)),
                ],
                // Keep third row visually balanced with the four-up row.
                const SizedBox(width: AppSpacing.xs),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
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
      color: selected ? AppColors.primaryBlue : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: selected
            ? AppColors.onPrimary.withValues(alpha: 0.22)
            : AppInk.splash,
        highlightColor: selected
            ? AppColors.onPrimary.withValues(alpha: 0.1)
            : AppInk.highlight,
        child: Ink(
          height: AppDayCheckboxes._chipHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected
                  ? AppColors.primaryBlue
                  : AppColors.secondaryGrey.withValues(alpha: 0.7),
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.captionStrong.copyWith(
                color: selected
                    ? AppColors.onPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
