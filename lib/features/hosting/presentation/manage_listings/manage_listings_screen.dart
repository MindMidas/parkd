import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/map/listing_next_available.dart';
import '../../../../core/models/listing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/listing_search.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../profile/providers/profile_providers.dart';
import '../create_listing/create_listing_screen.dart';
import 'edit/edit_listing_screen.dart';

// Searchable list of your listings from Riverpod
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
    final filtered = listings
        .where((l) => listingMatchesSearchQuery(l, _query))
        .toList();
    // Keep live listings first; expired date-specific ones sink to the bottom.
    filtered.sort((a, b) {
      final aExpired = listingIsExpiredSpecific(a);
      final bExpired = listingIsExpiredSpecific(b);
      if (aExpired != bExpired) return aExpired ? 1 : -1;
      return 0;
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(myListingsForCurrentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'Manage listings', showBack: true),
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
              value: listingsAsync,
              isEmpty: (listings) => listings.isEmpty,
              emptyTitle: 'No listings yet',
              emptyMessage: 'Publish a spot so guests can find and book it.',
              emptyActionLabel: 'Create listing',
              onEmptyAction: () {
                Navigator.of(context).push<void>(
                  AppPageRoute<void>(
                    builder: (_) => const CreateListingScreen(),
                  ),
                );
              },
              data: (listings) {
                final filtered = _filtered(listings);
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
                    return _ManageListingRow(
                      listing: listing,
                      onEdit: () {
                        Navigator.of(context).push<void>(
                          AppPageRoute<void>(
                            builder: (_) =>
                                EditListingScreen(listingId: listing.id),
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

class _ManageListingRow extends StatelessWidget {
  const _ManageListingRow({required this.listing, required this.onEdit});

  final Listing listing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final hero = listing.heroPhotoUrl;
    final expired = listingIsExpiredSpecific(listing);
    final spot = listing.spotLabel;
    final String? tertiary;
    final Color? tertiaryColor;
    if (expired) {
      tertiary = spot == null ? 'Expired' : 'Expired, $spot';
      tertiaryColor = AppColors.error;
    } else {
      tertiary = spot;
      tertiaryColor = null;
    }

    return AppMenuRow(
      leadingType: AppMenuLeadingType.parking,
      leadingImageProvider: hero != null && hero.isNotEmpty
          ? NetworkImage(hero)
          : null,
      title: listing.addressLine,
      subtitle: listing.localityLine.isNotEmpty ? listing.localityLine : null,
      tertiary: tertiary,
      tertiaryColor: tertiaryColor,
      rightKind: AppMenuRightKind.icon,
      rightIcon: Icons.edit_outlined,
      onTap: onEdit,
    );
  }
}
