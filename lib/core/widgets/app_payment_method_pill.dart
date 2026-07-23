// Tappable pill: brand + last4 + chevron or check when selected
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppPaymentMethodPill extends StatelessWidget {
  const AppPaymentMethodPill({
    super.key,
    required this.brand,
    required this.lastFour,
    this.onTap,
    this.selected = false,
  });

  final String brand;
  final String lastFour;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.primaryBlue),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(brand, style: AppTypography.paymentBrandItalic),
            Text(' •••• $lastFour', style: AppTypography.paymentPanBlue),
            const SizedBox(width: 4),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.chevron_right,
              size: 18,
              color: AppColors.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}
