// Blue-outline pill for saved cards
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AppSavedPaymentCardRow extends StatelessWidget {
  const AppSavedPaymentCardRow({
    super.key,
    required this.brand,
    required this.lastFour,
    required this.onTap,
  });

  final String brand;
  final String lastFour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.primaryBlue),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(brand, style: AppTypography.paymentBrandItalic),
                    Text(
                      ' •••• $lastFour',
                      style: AppTypography.paymentPanBlue,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.iconBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
