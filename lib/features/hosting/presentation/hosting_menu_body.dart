import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import 'active_bookings/active_bookings_screen.dart';
import 'create_listing/create_listing_screen.dart';
import 'earnings/earnings_screen.dart';
import 'manage_listings/manage_listings_screen.dart';
import 'past_bookings/past_bookings_screen.dart';

// Shared stack of nav tiles, hub body or full-screen hosting route
class HostingMenuBody extends StatelessWidget {
  const HostingMenuBody({super.key, this.topSpacing = AppSpacing.xl});

  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topSpacing),
        AppSettingsNavTile(
          icon: Icons.add_circle_outline_rounded,
          label: 'Create Listing',
          showDividerAbove: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CreateListingScreen(),
              ),
            );
          },
        ),
        AppSettingsNavTile(
          icon: Icons.tune_rounded,
          label: 'Manage Listings',
          showDividerAbove: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ManageListingsScreen(),
              ),
            );
          },
        ),
        AppSettingsNavTile(
          icon: Icons.directions_car_outlined,
          label: 'Active Bookings',
          showDividerAbove: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ActiveBookingsScreen(),
              ),
            );
          },
        ),
        AppSettingsNavTile(
          icon: Icons.history_rounded,
          label: 'Past Bookings',
          showDividerAbove: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PastBookingsScreen(),
              ),
            );
          },
        ),
        AppSettingsNavTile(
          icon: Icons.payments_outlined,
          label: 'Earnings',
          showDividerAbove: true,
          showDividerBelow: true,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EarningsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
