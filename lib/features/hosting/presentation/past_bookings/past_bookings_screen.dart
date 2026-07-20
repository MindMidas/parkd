import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/listing_search.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/profile_providers.dart';
import '../../../reservations/providers/reservations_providers.dart';
import 'past_booking_messages_screen.dart';
import '../../../../core/theme/app_colors.dart';

class PastBookingsScreen extends ConsumerStatefulWidget {
  const PastBookingsScreen({super.key});

  @override
  ConsumerState<PastBookingsScreen> createState() => _PastBookingsScreenState();
}

class _PastBookingsScreenState extends ConsumerState<PastBookingsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(myListingsForCurrentUserProvider);
    final reservationsAsync = ref.watch(hostPastReservationsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Past Bookings', showBack: true),
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
            child: listingsAsync.when(
              data: (listings) {
                return reservationsAsync.when(
                  data: (reservations) {
                    final withBookingIds = reservations
                        .map((r) => r.listingId)
                        .toSet();
                    final withBookings = listings
                        .where((l) => withBookingIds.contains(l.id))
                        .toList();
                    if (withBookings.isEmpty) {
                      return Center(
                        child: Text(
                          'No past bookings',
                          style: AppTypography.bodyMuted,
                        ),
                      );
                    }
                    final filtered = _filtered(withBookings);
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'No results match your search.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMuted,
                        ),
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
                        return _PastBookingRow(
                          listing: listing,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PastBookingMessagesScreen(listing: listing),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Text(
                      'Something went wrong',
                      style: AppTypography.bodyMuted,
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Something went wrong',
                  style: AppTypography.bodyMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastBookingRow extends StatelessWidget {
  const _PastBookingRow({required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hero = listing.heroPhotoUrl;
    return AppMenuRow(
      leadingType: AppMenuLeadingType.parking,
      leadingImageProvider: hero != null && hero.isNotEmpty
          ? NetworkImage(hero)
          : null,
      title: listing.addressLine,
      subtitle: listing.localityLine.isNotEmpty ? listing.localityLine : null,
      tertiary: listing.spotLabel,
      rightKind: AppMenuRightKind.chevron,
      onTap: onTap,
    );
  }
}
