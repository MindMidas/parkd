import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Grey disclaimer / info block. Reusable for "Changes will only apply..." style copy.
class AppInfoText extends StatelessWidget {
  const AppInfoText(
    this.text, {
    super.key,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        textAlign: textAlign,
      ),
    );
  }
}
