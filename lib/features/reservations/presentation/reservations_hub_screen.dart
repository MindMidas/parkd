import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import 'reservations_menu/reservations_menu_body.dart';

// Tab shell for driver reservations (no back; nested routes use AppTopBar)
class ReservationsHubScreen extends StatelessWidget {
  const ReservationsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Reservations',
        showBack: false,
        centerTitle: true,
        backgroundColor: kAppHubTitleBar,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: ReservationsMenuBody(topSpacing: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
