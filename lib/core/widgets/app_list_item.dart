import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/display_formatting.dart';
import 'app_divider.dart';

// List row + chevron; optional borders; label gets title case
class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    required this.label,
    this.onTap,
    this.showTopBorder = false,
    this.showBottomBorder = false,
    this.leadingIcon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool showTopBorder;
  final bool showBottomBorder;

  // Optional icon before the label
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showTopBorder) const AppDividerWide(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          minVerticalPadding: 14,
          visualDensity: VisualDensity.compact,
          leading: leadingIcon != null
              ? Icon(leadingIcon, size: 22, color: AppColors.iconGrey)
              : null,
          title: Text(formatTitleCaseWords(label), style: AppTypography.body),
          trailing: const Icon(
            Icons.keyboard_arrow_right_rounded,
            size: 22,
            color: AppColors.iconGrey,
          ),
          onTap: onTap,
        ),
        if (showBottomBorder) const AppDividerWide(),
      ],
    );
  }
}
