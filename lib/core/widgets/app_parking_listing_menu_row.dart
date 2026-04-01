import 'package:flutter/material.dart';

import '../models/listing.dart';
import '../theme/app_colors.dart';
import 'app_menu_row.dart';
import 'app_notification_badge.dart';

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
    this.trailingBadgeCount = 0,
  });

  final Listing? listing;
  final VoidCallback onTap;
  final String? tertiary;
  final String titleIfNoListing;
  final AppMenuRightKind rightKind;
  final IconData rightIcon;
  final int trailingBadgeCount;

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final heroUrl = l?.heroPhotoUrl?.trim() ?? '';
    final ImageProvider? parkingImage =
        heroUrl.isNotEmpty ? NetworkImage(heroUrl) : null;
    final title = l?.addressLine ?? titleIfNoListing;
    final locality = l?.localityLine ?? '';
    final tertiaryLine = tertiary ?? l?.spotLabel;

    final Widget? trailing = trailingBadgeCount > 0
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppNotificationBadge(count: trailingBadgeCount, compact: true),
              const SizedBox(width: 6),
              Icon(
                rightIcon,
                size: 22,
                color: AppColors.iconGrey,
              ),
            ],
          )
        : null;

    return AppMenuRow(
      leadingType: AppMenuLeadingType.parking,
      leadingImageProvider: parkingImage,
      title: title,
      subtitle: locality.isNotEmpty ? locality : null,
      tertiary: tertiaryLine,
      rightKind: rightKind,
      rightIcon: rightIcon,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
