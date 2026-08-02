import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';
import 'app_divider.dart';
import 'app_notification_badge.dart';

// Sole settings / hub navigation row API.
class AppNavTile extends StatelessWidget {
  const AppNavTile({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.onTap,
    this.badgeCount = 0,
    this.showDividerAbove = false,
    this.showDividerBelow = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final int badgeCount;
  final bool showDividerAbove;
  final bool showDividerBelow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDividerAbove) const AppDividerWide(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 4,
          ),
          minVerticalPadding: 14,
          visualDensity: VisualDensity.comfortable,
          splashColor: AppInk.splashSoft,
          hoverColor: AppInk.hover,
          leading: icon != null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBlue,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(icon, size: 22, color: AppColors.primaryBlue),
                  ),
                )
              : null,
          title: Text(label, style: AppTypography.bodyStrong),
          subtitle: subtitle != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle!, style: AppTypography.caption),
                )
              : null,
          trailing: UnconstrainedBox(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badgeCount > 0) ...[
                  AppNotificationBadge(count: badgeCount, compact: true),
                  const SizedBox(width: AppSpacing.xs),
                ],
                const Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 22,
                  color: AppColors.iconGrey,
                ),
              ],
            ),
          ),
          onTap: onTap == null
              ? null
              : () {
                  AppFeedback.selection(context);
                  onTap!();
                },
        ),
        if (showDividerBelow) const AppDividerWide(),
      ],
    );
  }
}
