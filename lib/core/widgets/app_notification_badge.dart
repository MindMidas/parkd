import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Blue count badge for bottom nav and hub menu rows.
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
    final fontSize = compact ? 10.0 : 11.0;
    final padH = compact ? 5.0 : 6.0;
    // Fixed height so ListTile trailing does not stretch the pill vertically.
    final fixedH = compact ? 18.0 : 20.0;
    final minW = compact ? 18.0 : 20.0;
    return SizedBox(
      height: fixedH,
      child: Container(
        constraints: BoxConstraints(minWidth: minW, maxHeight: fixedH),
        padding: EdgeInsets.symmetric(horizontal: padH),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(fixedH / 2),
          border: Border.all(color: AppColors.surface, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.onPrimary,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
