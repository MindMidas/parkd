import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// shell for map search UI (surface fill)
class AppMapSearchCard extends StatelessWidget {
  const AppMapSearchCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shadowColor: AppColors.shadowElevated,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
