import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/providers/notifications_providers.dart';
import 'active_bookings/active_bookings_screen.dart';
import 'create_listing/create_listing_screen.dart';
import 'earnings/earnings_screen.dart';
import 'manage_listings/manage_listings_screen.dart';
import 'past_bookings/past_bookings_screen.dart';

// Shared stack of nav tiles — hub body or full-screen hosting route
class HostingMenuBody extends ConsumerWidget {
  const HostingMenuBody({super.key, this.topSpacing = AppSpacing.xl});

  final double topSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingUnread = ref.watch(hostingBookingNotificationsCountProvider);
    final reviewUnread = ref.watch(hostingReviewNotificationsCountProvider);
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
          badgeCount: reviewUnread,
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
          badgeCount: bookingUnread,
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
              MaterialPageRoute<void>(builder: (_) => const EarningsScreen()),
            );
          },
        ),
      ],
    );
  }
}
