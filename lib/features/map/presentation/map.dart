import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/assets/parkd_assets.dart';
import '../../../core/map/map_constants.dart';
import '../../../core/map/mapbox_ornaments.dart';
import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    this.mapLayerId = 'parkd_main_map',
    this.initialLatitude = MapConstants.defaultLatitude,
    this.initialLongitude = MapConstants.defaultLongitude,
    this.initialZoom = MapConstants.defaultZoom,
    this.listings = const [],
    this.draftPin,
    this.useListingPinForDraft = false,
    this.recenterCameraOnDraftPinChange = true,
    this.onListingTap,
    this.onMapReady,
    this.onMapContentTap,
    this.onMapSurfaceTap,
    this.styleUri = MapboxStyles.MAPBOX_STREETS,
    this.onRecenterPressed,
    this.mapRecenterFabBottomOffset = kParkdMapRecenterFabBottomOffset,
    this.compassBottomMargin,
  });

  final String mapLayerId;

  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final List<Listing> listings;
  final ({double lat, double lon})? draftPin;

  final bool useListingPinForDraft;
  final bool recenterCameraOnDraftPinChange;

  final ValueChanged<Listing>? onListingTap;

  final ValueChanged<MapboxMap>? onMapReady;

  final void Function(double latitude, double longitude)? onMapContentTap;

  final VoidCallback? onMapSurfaceTap;

  final String styleUri;

  final Future<void> Function()? onRecenterPressed;

  final double mapRecenterFabBottomOffset;

  final double? compassBottomMargin;

  @override
  State<MapView> createState() => _MapViewState();
}

bool _sameListingIds(List<Listing> a, List<Listing> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return false;
  }
  return true;
}

class _MapViewState extends State<MapView> {
  static const double _listingPinScale = 0.68;
  static const double _draftPinScale = 0.70;

  MapboxMap? _map;
  PointAnnotationManager? _pointManager;
  Uint8List? _listingPinImage;
  Uint8List? _draftPinImage;
  Cancelable? _tapCancel;
  Cancelable? _dragCancel;

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _map = mapboxMap;
    await hideDefaultMapboxOrnaments(mapboxMap);
    final compassMb = widget.compassBottomMargin ?? 16.0;
    await applyParkdMapCompass(mapboxMap, marginBottom: compassMb);
    await hideStreetStylePoiLayers(mapboxMap);

    final listingBytes =
        (await rootBundle.load(ParkdAssets.mapPinPng)).buffer.asUint8List();
    final draftBytes =
        (await rootBundle.load(ParkdAssets.mapPinDraftPng)).buffer.asUint8List();
    _listingPinImage = listingBytes;
    _draftPinImage = draftBytes;

    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _tapCancel = _pointManager!.tapEvents(
      onTap: (PointAnnotation annotation) {
        final raw = annotation.customData?['listing_id'];
        if (raw == null) return;
        final id = raw.toString();
        if (id == 'draft') {
          return;
        }
        if (widget.onListingTap == null) return;
        for (final l in widget.listings) {
          if (l.id == id) {
            widget.onListingTap!(l);
            return;
          }
        }
      },
    );
    _dragCancel = _pointManager!.dragEvents(
      onEnd: (PointAnnotation annotation) {
        final raw = annotation.customData?['listing_id'];
        if (raw?.toString() != 'draft') return;
        final cb = widget.onMapContentTap;
        if (cb == null) return;
        final pos = annotation.geometry.coordinates;
        cb(pos.lat.toDouble(), pos.lng.toDouble());
      },
    );
    await _syncAnnotations();
    mapboxMap.setOnMapTapListener(_handleMapTap);

    // Location puck is turned on from HomeMapScreen when GPS permission is ok
    // stays off if denied so we do not show a fake dot
    widget.onMapReady?.call(mapboxMap);
  }

  Future<void> _syncAnnotations() async {
    final manager = _pointManager;
    final listingImg = _listingPinImage;
    final draftImg = _draftPinImage;
    if (manager == null || listingImg == null || draftImg == null) return;
    await manager.deleteAll();

    for (final listing in widget.listings) {
      await manager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(listing.longitude, listing.latitude),
          ),
          image: listingImg,
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: _listingPinScale,
          customData: {'listing_id': listing.id},
        ),
      );
    }

    final draft = widget.draftPin;
    if (draft != null) {
      final pinBytes =
          widget.useListingPinForDraft ? listingImg : draftImg;
      final scale = widget.useListingPinForDraft
          ? _listingPinScale
          : _draftPinScale;
      await manager.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: Position(draft.lon, draft.lat)),
          image: pinBytes,
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: scale,
          isDraggable: widget.onMapContentTap != null,
          customData: {'listing_id': 'draft'},
        ),
      );
    }
  }

  void _flyToDraft() {
    final d = widget.draftPin;
    final map = _map;
    if (d == null || map == null) return;
    unawaited(
      map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(d.lon, d.lat)),
          zoom: 16,
        ),
        null,
      ),
    );
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mapTapToggled = (widget.onMapContentTap != null) !=
        (oldWidget.onMapContentTap != null);
    if (!_sameListingIds(widget.listings, oldWidget.listings) ||
        widget.draftPin != oldWidget.draftPin ||
        mapTapToggled) {
      unawaited(_syncAnnotations());
    }
    if (widget.recenterCameraOnDraftPinChange &&
        widget.draftPin != oldWidget.draftPin &&
        widget.draftPin != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flyToDraft());
    }
  }

  void _handleMapTap(MapContentGestureContext ctx) {
    widget.onMapSurfaceTap?.call();
    final cb = widget.onMapContentTap;
    if (cb == null) return;
    final c = ctx.point.coordinates;
    cb(c.lat.toDouble(), c.lng.toDouble());
  }

  @override
  void dispose() {
    _tapCancel?.cancel();
    _dragCancel?.cancel();
    _map?.setOnMapTapListener(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mapbox iOS may read GlobalKey size before layout if constraints are loose
    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.sizeOf(context);
        final w = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mq.width;
        final h = constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mq.height;
        if (w <= 0 || h <= 0) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              MapWidget(
                key: ValueKey(widget.mapLayerId),
                styleUri: widget.styleUri,
                cameraOptions: CameraOptions(
                  center: Point(
                    coordinates: Position(
                      widget.initialLongitude,
                      widget.initialLatitude,
                    ),
                  ),
                  zoom: widget.initialZoom,
                ),
                onMapCreated: _onMapCreated,
              ),
              if (widget.onRecenterPressed != null)
                Positioned(
                  right: 12,
                  bottom: widget.mapRecenterFabBottomOffset,
                  child: Material(
                    elevation: 3,
                    shadowColor: AppColors.shadowMedium,
                    color: AppColors.surface,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => unawaited(widget.onRecenterPressed!()),
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: kParkdMapRecenterFabSize,
                        height: kParkdMapRecenterFabSize,
                        child: Icon(
                          Icons.my_location_rounded,
                          color: AppColors.primaryBlue,
                          size: 22,
                        ),
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
