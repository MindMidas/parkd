import 'package:flutter/material.dart';

// Listing photo area
class AppListingPhotoFrame extends StatelessWidget {
  const AppListingPhotoFrame({
    super.key,
    required this.child,
    this.overlay,
    this.onTap,
    this.aspectRatio = appListingPhotoFrameAspectRatio,
    this.borderRadius = 0,
  });

  final Widget child;
  final Widget? overlay;
  final VoidCallback? onTap;
  final double aspectRatio;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            ?overlay,
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}

// shared 4:3 for listing photos
const appListingPhotoFrameAspectRatio = 4 / 3;

// car pin size on listing photos
const appListingSpotMarkerDiameter = 34.0;
const appListingSpotMarkerIconSize = 16.0;
