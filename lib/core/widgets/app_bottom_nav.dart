import 'package:flutter/material.dart';

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
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _tabs = <({
    String label,
    IconData icon,
    IconData selectedIcon,
  })>[
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
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
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
                  color: selected ? AppColors.secondaryBlue : AppColors.transparent,
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
