import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/utils/listing_search.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/profile_providers.dart';
import 'edit/edit_listing_screen.dart';
import '../../../../core/theme/app_colors.dart';

// searchable list of user's listings from Riverpod
class ManageListingsScreen extends ConsumerStatefulWidget {
  const ManageListingsScreen({super.key});

  @override
  ConsumerState<ManageListingsScreen> createState() =>
      _ManageListingsScreenState();
}

class _ManageListingsScreenState extends ConsumerState<ManageListingsScreen> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Listing> _filtered(List<Listing> listings) {
    return listings
        .where((l) => listingMatchesSearchQuery(l, _query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(myListingsForCurrentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(
        title: 'Manage Listings',
        showBack: true,
      ),
      body: AppHubSearchListColumn(
        searchController: _searchController,
        searchHint: 'Search by address or spot',
        onSearchChanged: (value) => setState(() => _query = value),
        expandedChild: listingsAsync.when(
          data: (listings) {
            if (listings.isEmpty) {
              return const AppMutedBodyCenter('No listings yet');
            }
            final filtered = _filtered(listings);
            if (filtered.isEmpty) {
              return const AppMutedBodyCenter(
                'No results match your search.',
              );
            }
            return AppDividerSeparatedListView(
              itemCount: filtered.length,
              rowBuilder: (context, index) {
                final listing = filtered[index];
                return AppParkingListingMenuRow(
                  listing: listing,
                  rightKind: AppMenuRightKind.icon,
                  rightIcon: Icons.edit_outlined,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditListingScreen(
                          listingId: listing.id,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (err, _) =>
              const AppMutedBodyCenter('Something went wrong'),
        ),
      ),
    );
  }
}
