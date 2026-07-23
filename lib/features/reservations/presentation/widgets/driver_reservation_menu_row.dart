import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';
import '../../providers/reservations_providers.dart';

/// List row for a driver trip: square parking photo, address lines, reservation time
class DriverReservationMenuRow extends StatelessWidget {
  const DriverReservationMenuRow({
    super.key,
    required this.trip,
    required this.whenLabel,
    required this.onTap,
  });

  final DriverTripRow trip;
  final String whenLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = trip.listing;
    final heroUrl = l?.heroPhotoUrl?.trim() ?? '';
    final ImageProvider? parkingImage = heroUrl.isNotEmpty
        ? NetworkImage(heroUrl)
        : null;

    return AppMenuRow(
      leadingType: AppMenuLeadingType.parking,
      leadingImageProvider: parkingImage,
      title: l?.addressLine ?? 'Parking reservation',
      subtitle: l != null && l.localityLine.isNotEmpty ? l.localityLine : null,
      tertiary: whenLabel,
      rightKind: AppMenuRightKind.chevron,
      onTap: onTap,
    );
  }
}
