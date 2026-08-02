import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../assets/parkd_assets.dart';
import '../map/map_geo.dart';
import '../map/map_price_marker.dart';
import '../map/mapbox_runtime.dart';
import '../map/mapbox_ornaments.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_listing_photo_frame.dart';
import 'app_static_map_preview.dart';

// Small Mapbox preview (optional pin or approximate halo, interaction usually off)
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
    this.showPin = true,
    this.showApproximateHalo = false,
  });

  final double latitude;
  final double longitude;
  final double aspectRatio;
  final double zoom;
  final bool interactionEnabled;
  final String styleUri;

  // Mapbox icon-size for the pin asset
  final double pinIconSize;

  // Exact/specific location marker (pin asset). Ignored when showApproximateHalo.
  final bool showPin;

  // Soft radius + parking badge (Airbnb approximate area).
  final bool showApproximateHalo;

  @override
  State<AppMapboxPreview> createState() => _AppMapboxPreviewState();
}

class _AppMapboxPreviewState extends State<AppMapboxPreview> {
  static final int _haloFillColor = AppColors.primaryBlue.toARGB32();
  static final int _haloOutlineColor = AppColors.primaryBlue.toARGB32();

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

    if (widget.showApproximateHalo) {
      final areaManager =
          await mapboxMap.annotations.createPolygonAnnotationManager();
      final outer = approximateListingAreaRing(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      await areaManager.create(
        PolygonAnnotationOptions(
          geometry: Polygon(
            coordinates: [
              [for (final lngLat in outer) Position(lngLat[0], lngLat[1])],
            ],
          ),
          fillColor: _haloFillColor,
          fillOpacity: 0.22,
          fillOutlineColor: _haloOutlineColor,
        ),
      );
      final badge = await buildApproximateCenterBadgePng();
      final pointManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(widget.longitude, widget.latitude),
          ),
          image: badge,
          iconAnchor: IconAnchor.CENTER,
          iconSize: 1,
        ),
      );
      return;
    }

    if (!widget.showPin) return;

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
    final effectiveZoom = widget.showApproximateHalo
        ? (widget.zoom > 14.5 ? 14.2 : widget.zoom)
        : widget.zoom;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: supportsNativeMapboxMaps
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MapWidget(
                key: ValueKey(
                  '${widget.latitude}_${widget.longitude}_$effectiveZoom'
                  '_${widget.aspectRatio}_${widget.pinIconSize}'
                  '_${widget.showApproximateHalo}_${widget.showPin}',
                ),
                styleUri: widget.styleUri,
                viewport: CameraViewportState(
                  center: Point(
                    coordinates: Position(widget.longitude, widget.latitude),
                  ),
                  zoom: effectiveZoom,
                ),
                onMapCreated: _onMapCreated,
              ),
            )
          : AppStaticMapPreview(
              title: widget.showApproximateHalo
                  ? 'Approximate parking area'
                  : 'Parking area preview',
              message: widget.showApproximateHalo
                  ? 'Exact location will be provided after booking.'
                  : 'Interactive maps are available in Parkd on iOS and Android.',
              pinCount: 1,
              compact: true,
            ),
    );
  }
}

// Listing sheet / detail map: halo for general sharing, pin for specific.
class AppApproximateLocationMap extends StatelessWidget {
  const AppApproximateLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.showApproximateHalo,
    this.aspectRatio = appListingPhotoFrameAspectRatio,
  });

  final double latitude;
  final double longitude;
  final bool showApproximateHalo;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AppMapboxPreview(
      latitude: latitude,
      longitude: longitude,
      aspectRatio: aspectRatio,
      zoom: showApproximateHalo ? 14.2 : 15.5,
      interactionEnabled: false,
      showPin: !showApproximateHalo,
      showApproximateHalo: showApproximateHalo,
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
