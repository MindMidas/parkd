import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

// "Already have an account? Sign in" centered row
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
        Text(
          leadingText,
          style: AppTypography.caption,
        ),
        TextButton(
          onPressed: enabled ? onLinkPressed : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            linkText,
            style: AppTypography.captionLink,
          ),
        ),
      ],
    );
  }
}
