import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

// Compact text button (default caption link; optional app bar action style)
class AppCompactPrimaryTextButton extends StatelessWidget {
  const AppCompactPrimaryTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.fontSize = 12,
    this.labelStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final double fontSize;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final style = labelStyle ??
        AppTypography.captionLink.copyWith(fontSize: fontSize);
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.primaryBlue,
      ),
      child: Text(label, style: style),
    );
  }
}
