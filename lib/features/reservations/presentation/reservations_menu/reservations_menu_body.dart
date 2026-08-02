import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/notifications_providers.dart';
import '../active_reservations/active_reservations_screen.dart';
import '../past_reservations/past_reservations_screen.dart';

// Menu rows that push active vs past reservation lists
class ReservationsMenuBody extends ConsumerWidget {
  const ReservationsMenuBody({super.key, this.topSpacing = AppSpacing.sm});

  final double topSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(reservationNotificationsCountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppHubMenuIntro(
          lead:
              'See what\'s coming up, or look back at where you\'ve parked.',
        ),
        AppHubMenuSection(
          title: 'Your trips',
          topSpacing: topSpacing,
          children: [
            AppNavTile(
              icon: Icons.directions_car_outlined,
              label: 'Active reservations',
              subtitle: 'Upcoming and in progress',
              badgeCount: unread,
              showDividerAbove: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => const ActiveReservationsScreen(),
                  ),
                );
              },
            ),
            AppNavTile(
              icon: Icons.history_rounded,
              label: 'Past reservations',
              subtitle: 'Completed trips',
              showDividerAbove: true,
              showDividerBelow: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => const PastReservationsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg + scrollViewBottomInset(context)),
      ],
    );
  }
}
