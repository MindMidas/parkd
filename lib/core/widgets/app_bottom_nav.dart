import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_notification_badge.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

const double _kNavIconSize = 22;
const double _kPillRadius = 18;

// strip above home indicator
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

  int _badgeForIndex(int i) {
    return switch (i) {
      1 => reservationsBadgeCount,
      2 => hostingBadgeCount,
      3 => accountBadgeCount,
      _ => 0,
    };
  }

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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: selected
                      ? const Duration(milliseconds: 260)
                      : Duration.zero,
                  curve: selected ? Curves.easeOutCubic : Curves.linear,
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
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: AppNotificationBadge(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.navBarLabel.copyWith(
                color: AppColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
