import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/listing.dart';
import '../../../core/models/reservation_row.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/listing_search.dart';
import '../../../core/widgets/widgets.dart';
import '../../profile/providers/profile_providers.dart';

class HostBookingsByListingScreen extends ConsumerStatefulWidget {
  const HostBookingsByListingScreen({
    super.key,
    required this.title,
    required this.reservationsProvider,
    required this.whenEmptyList,
    required this.buildMessagesRoute,
  });

  final String title;
  final FutureProvider<List<ReservationRow>> reservationsProvider;
  final String whenEmptyList;
  final Widget Function(Listing listing) buildMessagesRoute;

  @override
  ConsumerState<HostBookingsByListingScreen> createState() =>
      _HostBookingsByListingScreenState();
}

class _HostBookingsByListingScreenState
    extends ConsumerState<HostBookingsByListingScreen> {
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
    final reservationsAsync = ref.watch(widget.reservationsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: widget.title,
        showBack: true,
      ),
      body: AppHubSearchListColumn(
        searchController: _searchController,
        searchHint: 'Search by address or spot',
        onSearchChanged: (value) => setState(() => _query = value),
        expandedChild: listingsAsync.when(
          data: (listings) {
            return reservationsAsync.when(
              data: (reservations) {
                final withBookingIds =
                    reservations.map((r) => r.listingId).toSet();
                final withBookings = listings
                    .where((l) => withBookingIds.contains(l.id))
                    .toList();
                if (withBookings.isEmpty) {
                  return AppMutedBodyCenter(widget.whenEmptyList);
                }
                final filtered = _filtered(withBookings);
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                widget.buildMessagesRoute(listing),
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
