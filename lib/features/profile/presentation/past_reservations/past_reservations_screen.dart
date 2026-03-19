import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/presentation/home_map_screen.dart';
import '../../providers/profile_providers.dart';
import '../active_reservations/reservation_details_screen.dart';

class PastReservationsScreen extends ConsumerWidget {
  const PastReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsForCurrentUserProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Past Reservations',
        showBack: true,
      ),
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
            child: const AppSearchField(),
          ),
          Expanded(
            child: listingsAsync.when(
              data: (listings) {
                if (listings.isEmpty) {
                  return Center(
                    child: Text(
                      'No reservations yet',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: listings.length * 2 + 1,
                  itemBuilder: (context, index) {
                    if (index.isEven) {
                      return const AppDivider();
                    }
                    final listing = listings[index ~/ 2];
                    return _PastReservationRow(
                      listing: listing,
                      onTap: () {
                        final cityPostal = [
                          listing.city,
                          if ((listing.postalCode ?? '').isNotEmpty)
                            listing.postalCode!,
                        ].where((part) => part.isNotEmpty).join(', ');
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReservationDetailsScreen(
                              hostName: 'Alex Morgan',
                              listingAddress: listing.addressLine,
                              cityPostal: cityPostal,
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
              error: (err, _) => Center(
                child: Text(
                  'Something went wrong',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
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

class _PastReservationRow extends StatelessWidget {
  const _PastReservationRow({
    required this.listing,
    required this.onTap,
  });

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cityPostal = [
      listing.city,
      if ((listing.postalCode ?? '').isNotEmpty) listing.postalCode!,
    ].where((part) => part.isNotEmpty).join(', ');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 4,
      ),
      leading: _ListingThumbnail(),
      title: Text(
        listing.addressLine,
        style: AppTypography.body.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        cityPostal,
        style: AppTypography.caption,
      ),
      trailing: _OpenReservationButton(onPressed: onTap),
      onTap: onTap,
    );
  }
}

class _ListingThumbnail extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.secondaryBlue.withValues(alpha: 0.2),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.local_parking,
        color: AppColors.primaryBlue,
        size: 28,
      ),
    );
  }
}

class _OpenReservationButton extends StatelessWidget {
  const _OpenReservationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: AppColors.primaryBlue,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox(
            width: 56,
            height: 44,
            child: Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
