import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Muted caption-style para (footnotes, disclaimers)
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
        style: AppTypography.caption.copyWith(height: 1.4),
        textAlign: textAlign,
      ),
    );
  }
}
