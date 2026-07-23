import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

// Looks like a text field but read-only; Copy button on the right, value ellipsizes
class AppReadonlyCopyField extends StatelessWidget {
  const AppReadonlyCopyField({
    super.key,
    required this.label,
    required this.value,
    required this.onCopy,
    this.displayText,
    this.copyLabel = 'Copy',
  });

  final String label;

  // Copied string; UI shows displayText ?? value
  final String value;

  final VoidCallback onCopy;

  // Optional shorter display; onCopy still uses value unless you change it there
  final String? displayText;

  final String copyLabel;

  String get _shown => displayText ?? value;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              _shown,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.monoBodyDense,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          AppPrimaryButton(
            label: copyLabel,
            icon: Icons.copy_rounded,
            onPressed: onCopy,
            compact: true,
            fullWidth: false,
            applyTitleCase: false,
          ),
        ],
      ),
    );
  }
}
