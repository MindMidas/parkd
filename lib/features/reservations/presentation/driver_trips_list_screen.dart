import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/display_formatting.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/reservations_providers.dart';
import 'active_reservations/reservation_details_screen.dart';
import 'driver_trip_list_helpers.dart';

class DriverTripsListScreen extends ConsumerStatefulWidget {
  const DriverTripsListScreen({
    super.key,
    required this.title,
    required this.tripsProvider,
    required this.whenEmpty,
  });

  final String title;
  final FutureProvider<List<DriverTripRow>> tripsProvider;
  final String whenEmpty;

  @override
  ConsumerState<DriverTripsListScreen> createState() =>
      _DriverTripsListScreenState();
}

class _DriverTripsListScreenState extends ConsumerState<DriverTripsListScreen> {
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

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(widget.tripsProvider);

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
        expandedChild: tripsAsync.when(
          data: (trips) {
            if (trips.isEmpty) {
              return AppMutedBodyCenter(widget.whenEmpty);
            }
            final filtered = trips
                .where(
                  (t) => driverTripRowMatchesSearchQuery(
                    reservation: t.reservation,
                    listing: t.listing,
                    query: _query,
                  ),
                )
                .toList();
            if (filtered.isEmpty) {
              return const AppMutedBodyCenter('No results match your search.');
            }
            return AppDividerSeparatedListView(
              itemCount: filtered.length,
              rowBuilder: (context, index) {
                final trip = filtered[index];
                return AppParkingListingMenuRow(
                  listing: trip.listing,
                  tertiary: formatDriverReservationWhenLabel(trip.reservation),
                  onTap: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => ReservationDetailsScreen(
                          reservation: trip.reservation,
                          listing: trip.listing,
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
          error: (err, st) =>
              const AppMutedBodyCenter('Something went wrong'),
        ),
      ),
    );
  }
}
