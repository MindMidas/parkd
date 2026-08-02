import 'package:flutter/material.dart';

// Listing photo area: fixed aspect, clip, optional overlay/tap
class AppListingPhotoFrame extends StatelessWidget {
  const AppListingPhotoFrame({
    super.key,
    required this.child,
    this.overlay,
    this.onTap,
    this.heroTag,
    this.aspectRatio = appListingPhotoFrameAspectRatio,
    this.borderRadius = 0,
  });

  final Widget child;
  final Widget? overlay;
  final VoidCallback? onTap;
  final Object? heroTag;
  final double aspectRatio;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final content = AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(fit: StackFit.expand, children: [child, ?overlay]),
      ),
    );
    final framed = onTap == null
        ? content
        : GestureDetector(onTap: onTap, child: content);
    if (heroTag == null) return framed;
    return Hero(tag: heroTag!, child: framed);
  }
}

// Shared 4:3 for listing photos
const appListingPhotoFrameAspectRatio = 4 / 3;

// Car marker on listing photos (annotate + read-only overlay); ~20% smaller than 42 / 20
const appListingSpotMarkerDiameter = 34.0;
const appListingSpotMarkerIconSize = 16.0;
