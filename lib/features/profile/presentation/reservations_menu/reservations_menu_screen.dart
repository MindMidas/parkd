import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/presentation/home_map_screen.dart';
import '../active_reservations/active_reservations_screen.dart';
import '../past_reservations/past_reservations_screen.dart';

class ReservationsMenuScreen extends StatelessWidget {
  const ReservationsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Reservations',
        showBack: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          AppListItem(
            label: 'Active Reservations',
            showTopBorder: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ActiveReservationsScreen(),
                ),
              );
            },
          ),
          AppListItem(
            label: 'Past Reservations',
            showTopBorder: true,
            showBottomBorder: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PastReservationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => HomeMapScreen(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
    );
  }
}
