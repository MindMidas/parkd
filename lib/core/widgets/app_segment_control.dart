import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';

class AppSegmentOption<T> {
  const AppSegmentOption({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Soft track + selected surface pill (heatmap / card brand / similar).
class AppSegmentControl<T> extends StatelessWidget {
  const AppSegmentControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<AppSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryGrey.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final option in options)
              Expanded(
                child: _SegmentCell<T>(
                  option: option,
                  selected: option.value == selected,
                  onTap: () {
                    if (option.value == selected) return;
                    AppFeedback.selection(context);
                    onChanged(option.value);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentCell<T> extends StatelessWidget {
  const _SegmentCell({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppSegmentOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.surface : AppColors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        splashColor: AppInk.splashSoft,
        highlightColor: AppInk.highlight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.icon != null) ...[
                Icon(
                  option.icon,
                  size: 16,
                  color: selected
                      ? AppColors.primaryBlue
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.captionStrong.copyWith(
                    letterSpacing: 0.15,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
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
