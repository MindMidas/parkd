import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_ink.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_feedback.dart';
import 'app_notification_badge.dart';

const double _kNavIconSize = 22;

// Icon + label strip height (home-indicator inset is separate).
const double _kNavStripHeight = 68;

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.reservationsBadgeCount = 0,
    this.hostingBadgeCount = 0,
    this.accountBadgeCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int reservationsBadgeCount;
  final int hostingBadgeCount;
  final int accountBadgeCount;

  int _badgeForIndex(int index) => switch (index) {
    1 => reservationsBadgeCount,
    2 => hostingBadgeCount,
    3 => accountBadgeCount,
    _ => 0,
  };

  static const _tabs = <({String label, IconData icon, IconData selectedIcon})>[
    (label: 'Map', icon: Icons.map_outlined, selectedIcon: Icons.map_rounded),
    (
      label: 'Reservations',
      icon: Icons.event_available_outlined,
      selectedIcon: Icons.event_available,
    ),
    (
      label: 'Hosting',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront,
    ),
    (
      label: 'Account',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: Material(
        color: AppColors.surface,
        elevation: 3,
        shadowColor: AppColors.shadowLow,
        surfaceTintColor: AppColors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: _kNavStripHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  10,
                  AppSpacing.xs,
                  6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: _NavItem(
                          label: _tabs[i].label,
                          icon: _tabs[i].icon,
                          selectedIcon: _tabs[i].selectedIcon,
                          badgeCount: _badgeForIndex(i),
                          selected: selectedIndex == i,
                          onTap: () {
                            // Always notify so re-tapping the active tab can
                            // pop nested routes back to the hub root.
                            AppFeedback.selection(context);
                            onDestinationSelected(i);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.badgeCount,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int badgeCount;
  final bool selected;
  final VoidCallback onTap;

  static final _splash = AppInk.splashSoft;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.iconBlue : AppColors.iconGrey;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: AppColors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  splashColor: _splash,
                  highlightColor: AppColors.transparent,
                  child: AnimatedContainer(
                    duration: AppMotion.nav,
                    curve: AppMotion.emphasized,
                    padding: EdgeInsets.symmetric(
                      horizontal: selected ? AppSpacing.sm : AppSpacing.xs,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.secondaryBlue
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: _kNavIconSize,
                      color: color,
                    ),
                  ),
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -6,
                  child: AppNotificationBadge(count: badgeCount, compact: true),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Material(
            color: AppColors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              splashColor: _splash,
              highlightColor: AppColors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs,
                  vertical: 2,
                ),
                child: AnimatedDefaultTextStyle(
                  duration: AppMotion.nav,
                  curve: AppMotion.emphasized,
                  style: AppTypography.navBarLabel.copyWith(
                    color: color,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
