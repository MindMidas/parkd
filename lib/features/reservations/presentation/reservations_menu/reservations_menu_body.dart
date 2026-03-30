import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../active_reservations/active_reservations_screen.dart';
import '../past_reservations/past_reservations_screen.dart';

// menu rows that push active vs past reservation lists
class ReservationsMenuBody extends StatelessWidget {
  const ReservationsMenuBody({super.key, this.topSpacing = AppSpacing.xl});

  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topSpacing),
        AppSettingsNavTile(
          icon: Icons.directions_car_outlined,
          label: 'Active Reservations',
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
