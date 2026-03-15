import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/listing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../home/presentation/home_map_screen.dart';
import '../../providers/profile_providers.dart';
import 'edit/edit_listing_screen.dart';

class ManageListingsScreen extends ConsumerWidget {
  const ManageListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsForCurrentUserProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppTopBar(
        title: 'Manage Listings',
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
            child: const _SearchField(),
          ),
          Expanded(
            child: listingsAsync.when(
              data: (listings) {
                if (listings.isEmpty) {
                  return Center(
                    child: Text(
                      'No listings yet',
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
                    return _ManageListingRow(
                      listing: listing,
                      onEdit: () {
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

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search',
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondary,
        ),
        prefixIcon: const Icon(Icons.search, color: AppColors.iconGrey),
        filled: true,
        fillColor: AppColors.secondaryBlue.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(32),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
    );
  }
}

/// ListTile-based row (like menu pages) so layout never overflows and dividers are consistent.
class _ManageListingRow extends StatelessWidget {
  const _ManageListingRow({
    required this.listing,
    required this.onEdit,
  });

  final Listing listing;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
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
        listing.subtitle,
        style: AppTypography.caption,
      ),
      trailing: _EditButton(onPressed: onEdit),
      onTap: onEdit,
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
        color: AppColors.secondaryBlue.withOpacity(0.2),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: AppColors.primaryBlue,
        child: InkWell(
          onTap: onPressed,
          child: const SizedBox(
            width: 44,
            height: 36,
            child: Icon(
              Icons.edit_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

