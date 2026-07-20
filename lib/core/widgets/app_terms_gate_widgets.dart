import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

// Full-screen terms gates (create listing, checkout); sign-up uses rich checkbox row

// Pinned footer: tappable checkbox + caption (publish / pay)
class AppTermsAgreementCheckboxRow extends StatelessWidget {
  const AppTermsAgreementCheckboxRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(child: Text(label, style: AppTypography.caption)),
        ],
      ),
    );
  }
}

// Numbered legal bit: "N. Title" + body (caption styles)
class AppTermsNumberedSection extends StatelessWidget {
  const AppTermsNumberedSection({
    super.key,
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number. $title', style: AppTypography.captionStrong),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: AppTypography.caption),
        ],
      ),
    );
  }
}
