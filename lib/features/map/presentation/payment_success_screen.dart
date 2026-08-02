import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../reservations/presentation/active_reservations/reservation_details_route_screen.dart';
import 'home_map_screen.dart';
import 'main_tab.dart';
import '../../../core/theme/app_colors.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key, this.reservationId});

  final String? reservationId;

  // Resets the stack back to the tab shell and returns the navigator that owns it
  NavigatorState _goHome(BuildContext context, {int tab = MainTab.map}) {
    final router = GoRouter.maybeOf(context);
    final nav = Navigator.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);

    final NavigatorState host;
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
      host = nav;
    } else if (rootNav.canPop()) {
      rootNav.popUntil((route) => route.isFirst);
      host = rootNav;
    } else {
      rootNav.pushAndRemoveUntil(
        AppPageRoute<void>(
          builder: (_) => HomeMapScreen(initialIndex: tab, hasTabInRoute: true),
        ),
        (route) => false,
      );
      host = rootNav;
    }

    router?.go('/home?tab=${MainTab.toQuery(tab)}');
    return host;
  }

  // Lands on the reservations tab with this trip's details on top, so back
  // returns to the reservations menu
  void _viewReservation(BuildContext context) {
    final id = reservationId?.trim() ?? '';
    final host = _goHome(context, tab: MainTab.reservations);
    if (id.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!host.mounted) return;
      host.push(
        AppPageRoute<void>(
          builder: (_) => ReservationDetailsRouteScreen(reservationId: id),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: AppOutcomeView(
          kind: AppOutcomeKind.success,
          title: 'Payment successful',
          message: "You're all set to park.",
          markSize: 72,
          gapAfterMark: AppSpacing.md,
          titleStyle: AppTypography.navTitle,
          messageStyle: AppTypography.caption,
          onClose: () => _goHome(context),
          actions: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Find this trip anytime under Reservations.',
                textAlign: TextAlign.center,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: 'View reservation',
                onPressed: () => _viewReservation(context),
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
