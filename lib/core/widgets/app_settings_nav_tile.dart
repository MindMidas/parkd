import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_divider.dart';
import 'app_notification_badge.dart';

// Settings list row: icon, title, optional subtitle, chevron
class AppSettingsNavTile extends StatelessWidget {
  const AppSettingsNavTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.subtitleStyle,
    this.badgeCount = 0,
    this.onTap,
    this.showDividerAbove = true,
    this.showDividerBelow = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  // Subtitle text style; defaults to caption if you leave it null.
  final TextStyle? subtitleStyle;
  // Unread count shown as a blue pill before the chevron.
  final int badgeCount;
  final VoidCallback? onTap;
  final bool showDividerAbove;
  final bool showDividerBelow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDividerAbove) const AppDividerWide(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          minVerticalPadding: 14,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            icon,
            size: 22,
            color: AppColors.iconGrey,
          ),
          title: Text(label, style: AppTypography.body),
          subtitle: subtitle != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: subtitleStyle ?? AppTypography.caption,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (badgeCount > 0) ...[
                AppNotificationBadge(count: badgeCount, compact: true),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 22,
                color: AppColors.iconGrey,
              ),
            ],
          ),
          onTap: onTap,
        ),
        if (showDividerBelow) const AppDividerWide(),
      ],
    );
  }
}
