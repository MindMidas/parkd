import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_listing_photo_frame.dart';

// Pin on photo using fractional coordinates.
class AppListingPhotoSpotOverlay extends StatelessWidget {
  const AppListingPhotoSpotOverlay({
    super.key,
    required this.child,
    this.markerFraction,
    this.markerDiameter = appListingSpotMarkerDiameter,
    this.markerIconSize = appListingSpotMarkerIconSize,
  });

  final Widget child;
  final Offset? markerFraction;
  final double markerDiameter;
  final double markerIconSize;

  @override
  Widget build(BuildContext context) {
    final f = markerFraction;
    if (f == null) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final markerX = f.dx * w;
        final markerY = f.dy * h;
        final markerRadius = markerDiameter / 2;

        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: child),
              Positioned(
                left: (markerX - markerRadius).clamp(0.0, w - markerRadius * 2),
                top: (markerY - markerRadius).clamp(0.0, h - markerRadius * 2),
                child: IgnorePointer(
                  child: Container(
                    width: markerRadius * 2,
                    height: markerRadius * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.onPrimary,
                      border: Border.all(
                        color: AppColors.primaryBlue,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowPin,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.directions_car_rounded,
                      color: AppColors.primaryBlue,
                      size: markerIconSize,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
