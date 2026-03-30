import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_divider.dart';
import 'app_form_helper_text.dart';
import 'app_section_title.dart';

// titled block + optional helper, optional top divider
class AppScreenSection extends StatelessWidget {
  const AppScreenSection({
    super.key,
    this.dividerAbove = false,
    required this.title,
    this.description,
    required this.child,
    this.horizontalPadding = AppSpacing.lg,
  });

  final bool dividerAbove;
  final String title;
  final String? description;
  final Widget child;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dividerAbove) ...[
          const SizedBox(height: AppSpacing.md),
          const AppDividerWide(),
          const SizedBox(height: AppSpacing.md),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSectionTitle(title),
              if (description != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppFormHelperText(description!),
              ],
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      ],
    );
  }
}
