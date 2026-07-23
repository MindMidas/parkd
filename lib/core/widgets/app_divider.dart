import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Hairline divider, width from parent
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

// Full-bleed lists use this name for clarity
class AppDividerWide extends StatelessWidget {
  const AppDividerWide({super.key});

  @override
  Widget build(BuildContext context) => const AppDivider();
}

// Divider inset when scroll is full width but content isn’t
class AppDividerInset extends StatelessWidget {
  const AppDividerInset({super.key, this.horizontal = AppSpacing.lg});

  final double horizontal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      child: const AppDivider(),
    );
  }
}
