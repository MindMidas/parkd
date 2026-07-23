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
  const HostingMenuBody({super.key, this.topSpacing = AppSpacing.sm});

  final double topSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingUnread = ref.watch(hostingBookingNotificationsCountProvider);
    final reviewUnread = ref.watch(hostingReviewNotificationsCountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppHubMenuIntro(
          lead:
              'Create and manage spots, follow guest bookings, and track '
              'earnings.',
        ),
        AppHubMenuSection(
          title: 'Listings',
          topSpacing: topSpacing,
          children: [
            AppNavTile(
              icon: Icons.add_circle_outline_rounded,
              label: 'Create Listing',
              subtitle: 'Add a new parking spot',
              showDividerAbove: true,
              onTap: () {
                Navigator.of(context).push<void>(
                  AppPageRoute<void>(
                    builder: (_) => const CreateListingScreen(),
                  ),
                );
              },
            ),
            AppNavTile(
              icon: Icons.tune_rounded,
              label: 'Manage Listings',
              subtitle: 'Edit, pause, or review',
              badgeCount: reviewUnread,
              showDividerAbove: true,
              showDividerBelow: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => const ManageListingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        AppHubMenuSection(
          title: 'Bookings',
          children: [
            AppNavTile(
              icon: Icons.directions_car_outlined,
              label: 'Active Bookings',
              subtitle: 'Guests arriving soon',
              badgeCount: bookingUnread,
              showDividerAbove: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => const ActiveBookingsScreen(),
                  ),
                );
              },
            ),
            AppNavTile(
              icon: Icons.history_rounded,
              label: 'Past Bookings',
              subtitle: 'Completed stays',
              showDividerAbove: true,
              showDividerBelow: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(
                    builder: (_) => const PastBookingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        AppHubMenuSection(
          title: 'Money',
          children: [
            AppNavTile(
              icon: Icons.payments_outlined,
              label: 'Earnings',
              subtitle: 'Payouts and totals',
              showDividerAbove: true,
              showDividerBelow: true,
              onTap: () {
                Navigator.of(context).push(
                  AppPageRoute<void>(builder: (_) => const EarningsScreen()),
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
