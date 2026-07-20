import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

// Card saved — outcome chrome then pop twice back to the list
class CardSuccessScreen extends StatelessWidget {
  const CardSuccessScreen({super.key, this.message = 'Card added'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: AppOutcomeView(
          kind: AppOutcomeKind.success,
          title: 'Success',
          message: message,
          buttonLabel: 'Close',
          primaryButtonIcon: Icons.close_rounded,
          markSize: 64,
          gapAfterMark: AppSpacing.md,
          titleStyle: AppTypography.navTitle,
          messageStyle: AppTypography.caption,
          onClose: () {
            var count = 0;
            Navigator.of(context).popUntil((_) => count++ >= 2);
          },
        ),
      ),
    );
  }
}
