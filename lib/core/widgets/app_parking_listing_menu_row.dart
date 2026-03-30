import 'package:flutter/material.dart';

import '../models/listing.dart';
import 'app_menu_row.dart';

// Parking thumbnail + address lines + optional third line (spot label, time, etc.)
class AppParkingListingMenuRow extends StatelessWidget {
  const AppParkingListingMenuRow({
    super.key,
    this.listing,
    required this.onTap,
    this.tertiary,
    this.titleIfNoListing = 'Parking reservation',
    this.rightKind = AppMenuRightKind.chevron,
    this.rightIcon = Icons.keyboard_arrow_right_rounded,
  });

  final Listing? listing;
  final VoidCallback onTap;
  final String? tertiary;
  final String titleIfNoListing;
  final AppMenuRightKind rightKind;
  final IconData rightIcon;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final heroUrl = l?.heroPhotoUrl?.trim() ?? '';
    final ImageProvider? parkingImage =
        heroUrl.isNotEmpty ? NetworkImage(heroUrl) : null;
    final title = l?.addressLine ?? titleIfNoListing;
    final locality = l?.localityLine ?? '';
    final tertiaryLine = tertiary ?? l?.spotLabel;

    return AppMenuRow(
      leadingType: AppMenuLeadingType.parking,
      leadingImageProvider: parkingImage,
      title: title,
      subtitle: locality.isNotEmpty ? locality : null,
      tertiary: tertiaryLine,
      rightKind: rightKind,
      rightIcon: rightIcon,
      onTap: onTap,
    );
  }
}
