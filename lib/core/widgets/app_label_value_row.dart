import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Row with a fixed-width bold label on the left and a value on the right.
/// Used for "From" / "To" style rows.
class AppLabelValueRow extends StatelessWidget {
  const AppLabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 60,
  });

  final String label;
  final String value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(value, style: AppTypography.body),
        ),
      ],
    );
  }
}
