import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_notification_badge.dart';

const double _kNavIconSize = 22;
const double _kPillRadius = 18;

// Strip above the home indicator (~30% shorter than the earlier ~60 logical px band)
const double _kNavStripHeight = 42;

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
    (label: 'Map', icon: Icons.map_outlined, selectedIcon: Icons.map_outlined),
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
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        Expanded(
                          child: _NavItem(
                            label: _tabs[i].label,
                            icon: _tabs[i].icon,
                            selectedIcon: _tabs[i].selectedIcon,
                            badgeCount: _badgeForIndex(i),
                            selected: selectedIndex == i,
                            onTap: () => onDestinationSelected(i),
                          ),
                        ),
                    ],
                  ),
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: AppColors.transparent,
                surfaceTintColor: AppColors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(_kPillRadius),
                  splashColor: AppColors.secondaryBlue.withValues(alpha: 0.35),
                  highlightColor: AppColors.transparent,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: selected ? AppSpacing.sm : AppSpacing.xs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.secondaryBlue
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(_kPillRadius),
                    ),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: _kNavIconSize,
                      color: selected ? AppColors.iconBlue : AppColors.iconGrey,
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
          const SizedBox(height: 1),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.navBarLabel.copyWith(color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }
}
