import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/notifications_providers.dart';
import '../active_reservations/active_reservations_screen.dart';
import '../past_reservations/past_reservations_screen.dart';

// menu rows that push active vs past reservation lists
class ReservationsMenuBody extends ConsumerWidget {
  const ReservationsMenuBody({super.key, this.topSpacing = AppSpacing.xl});

  final double topSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUnread = ref.watch(reservationsActiveMenuUnreadProvider);
    final pastUnread = ref.watch(reservationsPastMenuUnreadProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topSpacing),
        AppSettingsNavTile(
          icon: Icons.directions_car_outlined,
          label: 'Active Reservations',
          badgeCount: activeUnread,
          showDividerAbove: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ActiveReservationsScreen(),
              ),
            );
          },
        ),
        AppSettingsNavTile(
          icon: Icons.history_rounded,
          label: 'Past Reservations',
          badgeCount: pastUnread,
          showDividerAbove: true,
          showDividerBelow: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PastReservationsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
