import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/assets/parkd_assets.dart';
import '../../../core/map/map_approximate_clusters.dart';
import '../../../core/map/map_constants.dart';
import '../../../core/map/map_geo.dart';
import '../../../core/map/map_price_marker.dart';
import '../../../core/map/mapbox_runtime.dart';
import '../../../core/map/mapbox_ornaments.dart';
import '../../../core/models/listing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_map_overlay_chrome.dart';
import '../../../core/widgets/app_static_map_preview.dart';

// Mapbox explore map: Airbnb-style price pills + optional approximate halo
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
    this.selectedListingId,
    this.onListingTap,
    this.onApproximateAreaTap,
    this.approximatePrivacyHalo,
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

  // Listing currently open in the preview sheet (highlights its price pill).
  final String? selectedListingId;

  // Exact / specific-location listing pins.
  final ValueChanged<Listing>? onListingTap;

  // One approximate privacy cell — may contain many listings.
  final ValueChanged<List<Listing>>? onApproximateAreaTap;

  // Shaded area + center badge while an approximate listing preview is open.
  final ({double latitude, double longitude})? approximatePrivacyHalo;

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

bool _sameListingAnnotations(List<Listing> a, List<Listing> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final left = a[i];
    final right = b[i];
    if (left.id != right.id ||
        left.isApproximateLocation != right.isApproximateLocation ||
        left.latitude != right.latitude ||
        left.longitude != right.longitude ||
        left.minHourlyPrice != right.minHourlyPrice) {
      return false;
    }
  }
  return true;
}

class _MapViewState extends State<MapView> {
  static const double _listingPinScale = 0.68;
  static const double _draftPinScale = 0.70;
  static const double _pricePillScale = 1.0;
  static const double _pricePillSelectedScale = 1.08;
  static const String _mapTapInteractionId = 'parkd-map-surface-tap';
  static final int _haloFillColor = AppColors.primaryBlue.toARGB32();
  static final int _haloOutlineColor = AppColors.primaryBlue.toARGB32();

  MapboxMap? _map;
  PointAnnotationManager? _pointManager;
  PolygonAnnotationManager? _areaManager;
  Uint8List? _listingPinImage;
  Uint8List? _draftPinImage;
  Uint8List? _approxCenterBadge;
  Cancelable? _tapCancel;
  Cancelable? _areaTapCancel;
  Cancelable? _dragCancel;
  Map<String, List<Listing>> _approximateClusters = {};
  final Map<String, Uint8List> _priceMarkerCache = {};

  // Stable instance — a new CameraViewportState each build makes Mapbox
  late final ViewportState _initialViewport = CameraViewportState(
    center: Point(
      coordinates: Position(widget.initialLongitude, widget.initialLatitude),
    ),
    zoom: widget.initialZoom,
  );

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _map = mapboxMap;
    await hideDefaultMapboxOrnaments(mapboxMap);
    final compassMb = widget.compassBottomMargin ?? 16.0;
    await applyParkdMapCompass(
      mapboxMap,
      marginBottom: compassMb,
      marginRight: kParkdMapTrailingControlInset,
    );
    await hideStreetStylePoiLayers(mapboxMap);

    final listingBytes = (await rootBundle.load(
      ParkdAssets.mapPinPng,
    )).buffer.asUint8List();
    final draftBytes = (await rootBundle.load(
      ParkdAssets.mapPinDraftPng,
    )).buffer.asUint8List();
    _listingPinImage = listingBytes;
    _draftPinImage = draftBytes;
    _approxCenterBadge = await buildApproximateCenterBadgePng();

    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
    _areaManager = await mapboxMap.annotations.createPolygonAnnotationManager();
    _tapCancel = _pointManager!.tapEvents(
      onTap: (PointAnnotation annotation) {
        final data = annotation.customData;
        final clusterKey = data?['cluster_key'];
        if (clusterKey != null) {
          _emitApproximateAreaTap(clusterKey.toString());
          return;
        }
        _emitListingTap(data?['listing_id']);
      },
    );
    _areaTapCancel = _areaManager!.tapEvents(
      onTap: (PolygonAnnotation annotation) {
        final clusterKey = annotation.customData?['cluster_key'];
        if (clusterKey != null) {
          _emitApproximateAreaTap(clusterKey.toString());
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
    mapboxMap.addInteraction(
      TapInteraction.onMap(_handleMapTap),
      interactionID: _mapTapInteractionId,
    );

    widget.onMapReady?.call(mapboxMap);
  }

  Future<Uint8List> _priceMarkerBytes(String label, bool selected) async {
    final key = '$label|${selected ? '1' : '0'}';
    final cached = _priceMarkerCache[key];
    if (cached != null) return cached;
    final bytes = await buildMapPriceMarkerPng(
      label: label,
      selected: selected,
    );
    _priceMarkerCache[key] = bytes;
    return bytes;
  }

  void _emitListingTap(Object? rawListingId) {
    if (rawListingId == null) return;
    final id = rawListingId.toString();
    if (id == 'draft' || id == 'approx-center') return;
    final onTap = widget.onListingTap;
    if (onTap == null) return;
    for (final listing in widget.listings) {
      if (listing.id == id) {
        onTap(listing);
        return;
      }
    }
  }

  void _emitApproximateAreaTap(String clusterKey) {
    final group = _approximateClusters[clusterKey];
    if (group == null || group.isEmpty) return;
    final areaTap = widget.onApproximateAreaTap;
    if (areaTap != null) {
      areaTap(group);
      return;
    }
    if (group.length == 1) {
      widget.onListingTap?.call(group.first);
    }
  }

  bool _clusterContainsSelected(List<Listing> group) {
    final selected = widget.selectedListingId;
    if (selected == null) return false;
    return group.any((l) => l.id == selected);
  }

  Future<void> _syncAnnotations() async {
    final pointManager = _pointManager;
    final areaManager = _areaManager;
    final listingImg = _listingPinImage;
    final draftImg = _draftPinImage;
    final centerBadge = _approxCenterBadge;
    if (pointManager == null ||
        areaManager == null ||
        listingImg == null ||
        draftImg == null) {
      return;
    }
    await Future.wait([pointManager.deleteAll(), areaManager.deleteAll()]);

    final clusters = clusterApproximateListingsByCell(widget.listings);
    _approximateClusters = clusters;
    final halo = widget.approximatePrivacyHalo;
    final selectedId = widget.selectedListingId;

    // Explore: Airbnb price pills (no permanent rings).
    for (final entry in clusters.entries) {
      final clusterKey = entry.key;
      final group = entry.value;
      if (group.isEmpty) continue;
      final selected = _clusterContainsSelected(group);
      // While the approximate “Where you'll be” halo is open for this cluster,
      // hide the price pill and show the center badge instead.
      if (halo != null && selected) continue;

      final anchorListing = group.first;
      final anchor = obfuscateApproximateMapCenter(
        listingId: anchorListing.id,
        latitude: anchorListing.latitude,
        longitude: anchorListing.longitude,
      );
      final label = mapPriceMarkerLabel(
        anchorListing,
        clusterCount: group.length,
      );
      final pill = await _priceMarkerBytes(label, selected);
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(anchor.longitude, anchor.latitude),
          ),
          image: pill,
          iconAnchor: IconAnchor.CENTER,
          iconSize: selected ? _pricePillSelectedScale : _pricePillScale,
          customData: {'cluster_key': clusterKey},
        ),
      );
    }

    if (halo != null) {
      final outer = approximateListingAreaRing(
        latitude: halo.latitude,
        longitude: halo.longitude,
      );
      await areaManager.create(
        PolygonAnnotationOptions(
          geometry: Polygon(
            coordinates: [
              [for (final lngLat in outer) Position(lngLat[0], lngLat[1])],
            ],
          ),
          fillColor: _haloFillColor,
          fillOpacity: 0.18,
          fillOutlineColor: _haloOutlineColor,
        ),
      );
      if (centerBadge != null) {
        await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(halo.longitude, halo.latitude),
            ),
            image: centerBadge,
            iconAnchor: IconAnchor.CENTER,
            iconSize: 1,
            customData: {
              'listing_id': selectedId ?? 'approx-center',
            },
          ),
        );
      }
    }

    for (final listing in widget.listings) {
      if (listing.isApproximateLocation) continue;
      final selected = listing.id == selectedId;
      final label = mapPriceMarkerLabel(listing);
      final pill = await _priceMarkerBytes(label, selected);
      await pointManager.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(listing.longitude, listing.latitude),
          ),
          image: pill,
          iconAnchor: IconAnchor.CENTER,
          iconSize: selected ? _pricePillSelectedScale : _pricePillScale,
          customData: {'listing_id': listing.id},
        ),
      );
    }

    final draft = widget.draftPin;
    if (draft != null) {
      final pinBytes = widget.useListingPinForDraft ? listingImg : draftImg;
      final scale = widget.useListingPinForDraft
          ? _listingPinScale
          : _draftPinScale;
      await pointManager.create(
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
    final mapTapToggled =
        (widget.onMapContentTap != null) != (oldWidget.onMapContentTap != null);
    if (!_sameListingAnnotations(widget.listings, oldWidget.listings) ||
        widget.draftPin != oldWidget.draftPin ||
        widget.approximatePrivacyHalo != oldWidget.approximatePrivacyHalo ||
        widget.selectedListingId != oldWidget.selectedListingId ||
        mapTapToggled) {
      unawaited(_syncAnnotations());
    }
    if (widget.compassBottomMargin != oldWidget.compassBottomMargin) {
      final map = _map;
      if (map != null) {
        unawaited(
          applyParkdMapCompass(
            map,
            marginBottom: widget.compassBottomMargin ?? 16.0,
            marginRight: kParkdMapTrailingControlInset,
          ),
        );
      }
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
    _areaTapCancel?.cancel();
    _dragCancel?.cancel();
    _map?.removeInteraction(_mapTapInteractionId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        if (!supportsNativeMapboxMaps) {
          final isPinAdjustment = widget.onMapContentTap != null;
          return SizedBox(
            width: w,
            height: h,
            child: AppStaticMapPreview(
              title: isPinAdjustment
                  ? 'Using your selected address'
                  : 'Interactive map available on mobile',
              message: isPinAdjustment
                  ? 'Exact pin adjustment is available on iOS and Android. '
                        'On this device, the searched location will be used.'
                  : 'Browse parking spots in the list, or use Parkd on iOS or '
                        'Android for the interactive map.',
              pinCount: widget.draftPin == null ? widget.listings.length : 1,
              compact: false,
            ),
          );
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
                viewport: _initialViewport,
                onMapCreated: _onMapCreated,
              ),
              if (widget.onRecenterPressed != null)
                Positioned(
                  right: kParkdMapTrailingControlInset,
                  bottom: widget.mapRecenterFabBottomOffset,
                  child: AppMapFloatingIconButton(
                    tooltip: 'Recenter map',
                    icon: Icons.my_location_rounded,
                    size: kParkdMapRecenterFabSize,
                    onPressed: () => unawaited(widget.onRecenterPressed!()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
