import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/widgets.dart';
import 'reservations_menu_body.dart';

// Full-screen reservations menu with back (when not using the tab hub)
class ReservationsMenuScreen extends StatelessWidget {
  const ReservationsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Reservations', showBack: true),
      body: const ReservationsMenuBody(),
    );
  }
}
