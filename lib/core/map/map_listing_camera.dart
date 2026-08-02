import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'map_constants.dart';

// Frames the listing in the visible map band above a bottom sheet (padding insets)
Future<void> flyMapToListingPreview(
  MapboxMap map, {
  required double latitude,
  required double longitude,
  double zoom = MapConstants.defaultZoom,
  required double topPadding,
  required double bottomPadding,
}) {
  return map.flyTo(
    CameraOptions(
      center: Point(coordinates: Position(longitude, latitude)),
      zoom: zoom,
      padding: MbxEdgeInsets(
        top: topPadding,
        left: 0,
        bottom: bottomPadding,
        right: 0,
      ),
    ),
    null,
  );
}

// Restores camera with no edge padding (clears preview insets)
Future<void> flyMapToLatLonWithoutPadding(
  MapboxMap map, {
  required double latitude,
  required double longitude,
  double zoom = MapConstants.defaultZoom,
  double bearing = 0,
  double pitch = 0,
}) {
  return map.flyTo(
    CameraOptions(
      center: Point(coordinates: Position(longitude, latitude)),
      zoom: zoom,
      bearing: bearing,
      pitch: pitch,
      padding: MbxEdgeInsets(top: 0, left: 0, bottom: 0, right: 0),
    ),
    null,
  );
}
