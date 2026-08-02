import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Labeled group of hub AppNavTiles (Hosting / Reservations / Account).
class AppHubMenuSection extends StatelessWidget {
  const AppHubMenuSection({
    super.key,
    required this.title,
    required this.children,
    this.topSpacing = AppSpacing.md,
  });

  final String title;
  final List<Widget> children;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topSpacing),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(title, style: AppTypography.sectionTitle),
        ),
        ...children,
      ],
    );
  }
}
