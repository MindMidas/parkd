import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/scroll_view_bottom_inset.dart';
import '../../../core/widgets/widgets.dart';
import 'home_map_screen.dart';
import '../../../app/main_tab.dart';
import '../../../core/theme/app_colors.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  Future<void> _openDirections() async {
    final url = Uri.parse(
      'https://maps.apple.com/?daddr=$latitude,$longitude&dirflg=d',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _goHome(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final nav = Navigator.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);

    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    } else if (rootNav.canPop()) {
      rootNav.popUntil((route) => route.isFirst);
    } else {
      rootNav.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => const HomeMapScreen(
            initialIndex: MainTab.map,
            hasTabInRoute: true,
          ),
        ),
        (route) => false,
      );
    }

    router?.go('/home?tab=${MainTab.toQuery(MainTab.map)}');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = scrollViewBottomInset(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Spacer(flex: 3),
            Center(
              child: AppOutcomeHeadline(
                kind: AppOutcomeKind.success,
                title: 'Payment Successful',
                message: "You're all set to park!",
                markSize: 72,
                gapAfterMark: AppSpacing.md,
                titleStyle: AppTypography.navTitle,
                messageStyle: AppTypography.caption,
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
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
                    label: 'Get directions',
                    icon: Icons.explore_outlined,
                    onPressed: () => unawaited(_openDirections()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppSecondaryButton(
                    label: 'Close',
                    onPressed: () => _goHome(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.lg + bottomInset),
          ],
        ),
      ),
    );
  }
}
