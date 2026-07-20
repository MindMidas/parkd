import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_divider.dart';

// Line through the middle with title in the center
class AppSectionDividerTitle extends StatelessWidget {
  const AppSectionDividerTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        children: [
          const Expanded(child: AppDivider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(text, style: AppTypography.caption),
          ),
          const Expanded(child: AppDivider()),
        ],
      ),
    );
  }
}
