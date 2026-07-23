import 'package:flutter/material.dart';

import '../theme/app_typography.dart';
import 'app_compact_primary_text_button.dart';

// "Already have an account? Sign in" style centered row
class AppMutedLinkRow extends StatelessWidget {
  const AppMutedLinkRow({
    super.key,
    required this.leadingText,
    required this.linkText,
    required this.onLinkPressed,
    this.enabled = true,
  });

  final String leadingText;
  final String linkText;
  final VoidCallback? onLinkPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(leadingText, style: AppTypography.caption),
        AppCompactPrimaryTextButton(
          label: linkText,
          onPressed: onLinkPressed,
          enabled: enabled,
        ),
      ],
    );
  }
}
