import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import 'home_map_screen.dart';
import 'main_tab.dart';
import '../../../core/theme/app_colors.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  void _goHome(BuildContext context, {int tab = MainTab.map}) {
    final router = GoRouter.maybeOf(context);
    final nav = Navigator.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);

    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    } else if (rootNav.canPop()) {
      rootNav.popUntil((route) => route.isFirst);
    } else {
      rootNav.pushAndRemoveUntil(
        AppPageRoute<void>(
          builder: (_) => HomeMapScreen(initialIndex: tab, hasTabInRoute: true),
        ),
        (route) => false,
      );
    }

    router?.go('/home?tab=${MainTab.toQuery(tab)}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: AppOutcomeView(
          kind: AppOutcomeKind.success,
          title: 'Payment Successful',
          message: "You're all set to park!",
          markSize: 72,
          gapAfterMark: AppSpacing.md,
          titleStyle: AppTypography.navTitle,
          messageStyle: AppTypography.caption,
          onClose: () => _goHome(context),
          actions: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You can chat with the host, view\ndetails, or get directions anytime in\nProfile → Reservations.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Or',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: 'View reservation',
                icon: Icons.local_parking_rounded,
                onPressed: () => _goHome(context, tab: MainTab.reservations),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSecondaryButton(
                label: 'Close',
                onPressed: () => _goHome(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
