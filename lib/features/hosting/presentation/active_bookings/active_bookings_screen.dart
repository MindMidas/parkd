import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/models/reservation_row.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/listing_search.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/notifications_providers.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../reservations/providers/reservations_providers.dart';
import 'booking_messages_screen.dart';

class ActiveBookingsScreen extends ConsumerStatefulWidget {
  const ActiveBookingsScreen({super.key});

  @override
  ConsumerState<ActiveBookingsScreen> createState() =>
      _ActiveBookingsScreenState();
}

class _ActiveBookingsScreenState extends ConsumerState<ActiveBookingsScreen> {
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
    return listings.where((l) => listingMatchesSearchQuery(l, _query)).toList();
  }

  int _unreadForListing(
    String listingId,
    List<ReservationRow> reservations,
    Map<String, int> byReservation,
  ) {
    var total = 0;
    for (final reservation in reservations) {
      if (reservation.listingId != listingId) continue;
      total += byReservation[reservation.id] ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(myListingsForCurrentUserProvider);
    final reservationsAsync = ref.watch(hostActiveReservationsProvider);
    final unreadByReservation = ref.watch(
      unreadBookingEventCountByReservationProvider,
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Active bookings', showBack: true),
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
            child: _buildBody(
              listingsAsync,
              reservationsAsync,
              unreadByReservation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Listing>> listingsAsync,
    AsyncValue<List<ReservationRow>> reservationsAsync,
    Map<String, int> unreadByReservation,
  ) {
    if (listingsAsync.isLoading || reservationsAsync.isLoading) {
      return const AppPageStatus.loading();
    }
    if (listingsAsync.hasError || reservationsAsync.hasError) {
      return const AppPageStatus.error();
    }

    final listings = listingsAsync.requireValue;
    final reservations = reservationsAsync.requireValue;
    final counts = <String, int>{};
    for (final r in reservations) {
      counts[r.listingId] = (counts[r.listingId] ?? 0) + 1;
    }
    final withBookings = listings
        .where((l) => (counts[l.id] ?? 0) > 0)
        .toList();

    if (withBookings.isEmpty) {
      return const AppPageStatus.empty(
        title: 'No active bookings',
        message: 'When guests book your spots, they will show up here.',
      );
    }

    final filtered = _filtered(withBookings);
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
        final listing = filtered[index ~/ 2];
        return _ActiveBookingRow(
          listing: listing,
          bookingCount: counts[listing.id] ?? 0,
          badgeCount: _unreadForListing(
            listing.id,
            reservations,
            unreadByReservation,
          ),
          onTap: () {
            Navigator.of(context).push<void>(
              AppPageRoute<void>(
                builder: (_) => BookingMessagesScreen(listing: listing),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActiveBookingRow extends StatelessWidget {
  const _ActiveBookingRow({
    required this.listing,
    required this.bookingCount,
    required this.badgeCount,
    required this.onTap,
  });

  final Listing listing;
  final int bookingCount;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hero = listing.heroPhotoUrl;
    final bookingLabel = bookingCount == 1
        ? '1 active booking'
        : '$bookingCount active bookings';
    final spot = listing.spotLabel;
    return AppMenuRow(
      leadingType: AppMenuLeadingType.parking,
      leadingImageProvider: hero != null && hero.isNotEmpty
          ? NetworkImage(hero)
          : null,
      title: listing.addressLine,
      subtitle: listing.localityLine.isNotEmpty ? listing.localityLine : null,
      tertiary: (spot != null && spot.isNotEmpty)
          ? '$spot, $bookingLabel'
          : bookingLabel,
      rightKind: AppMenuRightKind.chevron,
      badgeCount: badgeCount,
      onTap: onTap,
    );
  }
}
