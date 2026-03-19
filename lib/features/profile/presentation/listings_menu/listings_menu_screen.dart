import 'package:flutter/material.dart';

import '../create_listing/create_listing_screen.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/presentation/home_map_screen.dart';
import '../active_bookings/active_bookings_screen.dart';
import '../manage_listings/manage_listings_screen.dart';
import '../past_bookings/past_bookings_screen.dart';

class ListingsMenuScreen extends StatelessWidget {
  const ListingsMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Listings',
        showBack: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          AppListItem(
            label: 'Create Listing',
            showTopBorder: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateListingScreen(),
                ),
              );
            },
          ),
          AppListItem(
            label: 'Manage Listings',
            showTopBorder: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ManageListingsScreen(),
                ),
              );
            },
          ),
          AppListItem(
            label: 'Active Bookings',
            showTopBorder: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ActiveBookingsScreen(),
                ),
              );
            },
          ),
          AppListItem(
            label: 'Past Bookings',
            showTopBorder: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PastBookingsScreen(),
                ),
              );
            },
          ),
          const AppListItem(
            label: 'Earnings',
            showTopBorder: true,
            showBottomBorder: true,
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

