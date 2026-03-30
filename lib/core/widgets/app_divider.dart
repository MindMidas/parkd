import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// line divider, width from parent
class AppDivider extends StatelessWidget {
  const AppDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      color: AppColors.secondaryGrey,
    );
  }
}

// bleed lists use this name for clarity
class AppDividerWide extends StatelessWidget {
  const AppDividerWide({super.key});

  @override
  Widget build(BuildContext context) => const AppDivider();
}
