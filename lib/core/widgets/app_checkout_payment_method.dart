// Checkout payment row inside the same titled outline card as price breakdown. README.md
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_display_fields.dart';

class AppCheckoutPaymentMethodField extends StatelessWidget {
  const AppCheckoutPaymentMethodField({
    super.key,
    required this.brand,
    required this.lastFour,
    required this.onChangePressed,
    this.title = 'Payment method',
  });

  final String brand;
  final String lastFour;
  final VoidCallback onChangePressed;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = title.trim().isEmpty ? 'Payment method' : title.trim();
    return AppDisplayTitledOutlineCard(
      title: t,
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: onChangePressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.body,
                      children: [
                        TextSpan(text: brand, style: AppTypography.bodyStrong),
                        TextSpan(
                          text: ' •••• $lastFour',
                          style: AppTypography.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.iconGrey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
