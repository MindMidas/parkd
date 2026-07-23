import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// Password rule line (icon + label)
class AppRequirementCheckRow extends StatelessWidget {
  const AppRequirementCheckRow({
    super.key,
    required this.label,
    required this.state,
    this.leading,
    this.trailing,
  });

  final String label;
  final RequirementRowState state;

  // Custom left icon instead of default state icon
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTypography.caption.copyWith(
      color: switch (state) {
        RequirementRowState.met => AppColors.success,
        RequirementRowState.unmet => AppColors.error,
        RequirementRowState.neutral => AppColors.textSecondary,
      },
      height: 1.25,
    );

    final icon = switch (state) {
      RequirementRowState.met => const Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: AppColors.success,
      ),
      RequirementRowState.unmet => const Icon(
        Icons.cancel_rounded,
        size: 18,
        color: AppColors.error,
      ),
      RequirementRowState.neutral => Icon(
        Icons.circle_outlined,
        size: 18,
        color: AppColors.textSecondary.withValues(alpha: 0.55),
      ),
    };

    final lead = leading ?? icon;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 18,
            child: Align(alignment: Alignment.centerLeft, child: lead),
          ),
          Expanded(child: Text(label, style: textStyle)),
          ?trailing,
        ],
      ),
    );
  }
}

enum RequirementRowState { neutral, met, unmet }
