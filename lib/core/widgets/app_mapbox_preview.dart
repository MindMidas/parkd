import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../assets/parkd_assets.dart';
import '../map/mapbox_runtime.dart';
import '../map/mapbox_ornaments.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_listing_photo_frame.dart';
import 'app_static_map_preview.dart';

// Small Mapbox preview (optional pin, interaction usually off)
class AppMapboxPreview extends StatefulWidget {
  const AppMapboxPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.aspectRatio = appListingPhotoFrameAspectRatio,
    this.zoom = 16,
    this.interactionEnabled = false,
    this.styleUri = MapboxStyles.MAPBOX_STREETS,
    this.pinIconSize = 0.68,
  });

  final double latitude;
  final double longitude;
  final double aspectRatio;
  final double zoom;
  final bool interactionEnabled;
  final String styleUri;

  // Mapbox icon-size for the pin asset
  final double pinIconSize;

  @override
  State<AppMapboxPreview> createState() => _AppMapboxPreviewState();
}

class _AppMapboxPreviewState extends State<AppMapboxPreview> {
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    await hideDefaultMapboxOrnaments(mapboxMap);
    await applyParkdMapCompass(mapboxMap, marginBottom: 16);
    await hideStreetStylePoiLayers(mapboxMap);

    if (!widget.interactionEnabled) {
      await mapboxMap.gestures.updateSettings(
        GesturesSettings(
          rotateEnabled: false,
          pinchToZoomEnabled: false,
          scrollEnabled: false,
          pitchEnabled: false,
          doubleTapToZoomInEnabled: false,
          doubleTouchToZoomOutEnabled: false,
          quickZoomEnabled: false,
        ),
      );
    }

    final image = (await rootBundle.load(
      ParkdAssets.mapPinPng,
    )).buffer.asUint8List();
    final manager = await mapboxMap.annotations.createPointAnnotationManager();
    await manager.create(
      PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(widget.longitude, widget.latitude),
        ),
        image: image,
        iconAnchor: IconAnchor.BOTTOM,
        iconSize: widget.pinIconSize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: supportsNativeMapboxMaps
          ? MapWidget(
              key: ValueKey(
                '${widget.latitude}_${widget.longitude}_${widget.zoom}_${widget.aspectRatio}_${widget.pinIconSize}',
              ),
              styleUri: widget.styleUri,
              viewport: CameraViewportState(
                center: Point(
                  coordinates: Position(widget.longitude, widget.latitude),
                ),
                zoom: widget.zoom,
              ),
              onMapCreated: _onMapCreated,
            )
          : const AppStaticMapPreview(
              title: 'Parking area preview',
              message:
                  'Interactive maps are available in Parkd on iOS and Android.',
              pinCount: 1,
              compact: true,
            ),
    );
  }
}

// Corner circle on a map preview stack (camera / gallery affordance)
class AppMapStackCornerCircleBadge extends StatelessWidget {
  const AppMapStackCornerCircleBadge({
    super.key,
    this.bottom = AppSpacing.md,
    this.right = AppSpacing.md,
    this.icon = Icons.camera_alt_outlined,
    this.iconSize = 18,
    this.diameter = 36,
  });

  final double bottom;
  final double right;
  final IconData icon;
  final double iconSize;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: bottom,
      right: right,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.secondaryGrey),
        ),
        child: Icon(icon, size: iconSize, color: AppColors.iconGrey),
      ),
    );
  }
}
