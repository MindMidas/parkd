import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppNotificationBadge extends StatelessWidget {
  const AppNotificationBadge({
    super.key,
    required this.count,
    this.compact = false,
  });

  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    final size = compact ? 18.0 : 20.0;
    return Semantics(
      label: '$count unread notifications',
      excludeSemantics: true,
      // Fixed height so ListTile trailing stretch cannot elongate the pill
      child: Container(
        height: size,
        constraints: BoxConstraints(minWidth: size),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.surface, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: compact ? 10 : 11,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
