import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

// Compact text link (same style as AppMutedLinkRow / captionLink)
class AppCompactPrimaryTextButton extends StatelessWidget {
  const AppCompactPrimaryTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.fontSize = 12,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: AppTypography.captionLink.copyWith(fontSize: fontSize),
      ),
    );
  }
}
