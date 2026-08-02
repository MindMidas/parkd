import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/reservation_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/listing_search.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/reservations_providers.dart';
import '../active_reservations/reservation_details_screen.dart';
import '../widgets/driver_reservation_menu_row.dart';

// Driver: completed or cancelled trips you booked
class PastReservationsScreen extends ConsumerStatefulWidget {
  const PastReservationsScreen({super.key});

  @override
  ConsumerState<PastReservationsScreen> createState() =>
      _PastReservationsScreenState();
}

class _PastReservationsScreenState
    extends ConsumerState<PastReservationsScreen> {
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

  bool _tripMatches(DriverTripRow t, String q) {
    if (q.isEmpty) return true;
    final l = t.listing;
    if (l != null && listingMatchesSearchQuery(l, q)) return true;
    return t.reservation.id.toLowerCase().contains(q.trim().toLowerCase());
  }

  static String _whenLabel(ReservationRow r) {
    final d = DateFormat('MMM d').format(r.startTime.toLocal());
    final t = DateFormat('h:mm a').format(r.startTime.toLocal());
    return '$d · $t';
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(driverPastTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Past reservations', showBack: true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppListScreenSearchPanel(
              controller: _searchController,
              hintText: 'Search by address or spot',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: AppAsyncBody(
              value: tripsAsync,
              isEmpty: (trips) => trips.isEmpty,
              emptyTitle: 'No past reservations',
              emptyMessage: 'Completed and cancelled trips will land here.',
              data: (trips) {
                final filtered = trips
                    .where((t) => _tripMatches(t, _query))
                    .toList();
                if (filtered.isEmpty) {
                  return const AppPageStatus.empty(
                    title: 'No matches',
                    message: 'Try a different address or spot name.',
                  );
                }
                return ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: filtered.length * 2 + 1,
                  itemBuilder: (context, index) {
                    if (index.isEven) {
                      return const AppDividerWide();
                    }
                    final trip = filtered[index ~/ 2];
                    return DriverReservationMenuRow(
                      trip: trip,
                      whenLabel: _whenLabel(trip.reservation),
                      onTap: () {
                        Navigator.of(context).push<void>(
                          AppPageRoute<void>(
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
            ),
          ),
        ],
      ),
    );
  }
}
