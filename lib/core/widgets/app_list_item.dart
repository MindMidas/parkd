import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_divider.dart';

// List item with optional borders. Label is displayed in title case (first letter of each word capitalized).
class AppListItem extends StatelessWidget {
  const AppListItem({
    super.key,
    required this.label,
    this.onTap,
    this.showTopBorder = false,
    this.showBottomBorder = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool showTopBorder;
  final bool showBottomBorder;

  static String _formatLabel(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showTopBorder) const AppDivider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minVerticalPadding: 14,
          visualDensity: VisualDensity.compact,
          title: Text(
            _formatLabel(label),
            style: AppTypography.body,
          ),
          trailing: const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.iconGrey,
          ),
          onTap: onTap,
        ),
        if (showBottomBorder) const AppDivider(),
      ],
    );
  }
}

