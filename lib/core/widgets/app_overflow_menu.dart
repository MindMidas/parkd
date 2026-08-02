import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';

class AppOverflowMenuItem {
  const AppOverflowMenuItem({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool destructive;
}

// App-bar overflow with Parkd row chrome (not stock ListTile menus).
class AppOverflowMenuButton extends StatelessWidget {
  const AppOverflowMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.tooltip = 'More',
    this.icon = Icons.more_vert_rounded,
  });

  final List<AppOverflowMenuItem> items;
  final ValueChanged<String> onSelected;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: tooltip,
      offset: const Offset(0, 8),
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.shadowMedium,
      surfaceTintColor: AppColors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: AppColors.secondaryGrey.withValues(alpha: 0.55),
        ),
      ),
      icon: Icon(icon, color: AppColors.primaryBlue, size: 22),
      splashRadius: 22,
      onSelected: (value) {
        AppFeedback.selection(context);
        onSelected(value);
      },
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<String>(
            value: item.value,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: item.destructive
                      ? AppColors.error
                      : AppColors.iconGrey,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.body.copyWith(
                      color: item.destructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      // Stronger press flash on the trigger icon.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) return AppInk.highlight;
          if (states.contains(WidgetState.hovered)) return AppInk.hover;
          return AppInk.splash.withValues(alpha: 0.12);
        }),
      ),
    );
  }
}
