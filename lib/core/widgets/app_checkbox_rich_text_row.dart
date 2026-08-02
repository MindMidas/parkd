import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

// Checkbox + rich text label (tappable spans in terms)
class AppCheckboxRichTextRow extends StatelessWidget {
  const AppCheckboxRichTextRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labelSpan,
    this.enabled = true,
    this.checkboxSize = 20,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final InlineSpan labelSpan;
  final bool enabled;
  final double checkboxSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: checkboxSize,
          height: checkboxSize,
          child: Checkbox(
            value: value,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primaryBlue;
              }
              return AppColors.secondaryGrey;
            }),
            side: const BorderSide(color: AppColors.secondaryGrey),
            onChanged: enabled ? onChanged : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text.rich(labelSpan),
          ),
        ),
      ],
    );
  }
}
