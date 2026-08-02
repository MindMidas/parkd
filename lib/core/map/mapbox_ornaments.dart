import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'map_constants.dart';

Future<void> hideDefaultMapboxOrnaments(MapboxMap mapboxMap) async {
  await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  await mapboxMap.logo.updateSettings(LogoSettings(enabled: false));
  await mapboxMap.attribution.updateSettings(
    AttributionSettings(enabled: false),
  );
}

Future<void> applyParkdMapCompass(
  MapboxMap mapboxMap, {
  double marginBottom = 16,
  double marginRight = kParkdMapTrailingControlInset,
}) async {
  await mapboxMap.compass.updateSettings(
    CompassSettings(
      enabled: true,
      position: OrnamentPosition.BOTTOM_RIGHT,
      marginBottom: marginBottom,
      marginRight: marginRight,
      fadeWhenFacingNorth: false,
      clickable: true,
    ),
  );
}

// turn off stock POI/transit/airport symbol layers so app pins read cleaner
Future<void> hideStreetStylePoiLayers(MapboxMap mapboxMap) async {
  final style = mapboxMap.style;
  try {
    final layers = await style.getStyleLayers();
    for (final info in layers) {
      if (info == null) continue;
      if (!_isStockPoiStyleLayerId(info.id)) continue;
      try {
        await style.setStyleLayerProperty(info.id, 'visibility', 'none');
      } catch (_) {}
    }
  } catch (_) {}
}

bool _isStockPoiStyleLayerId(String id) {
  final l = id.toLowerCase();
  if (l.contains('poi')) return true;
  if (l.contains('transit-label')) return true;
  if (l.contains('airport-label')) return true;
  return false;
}
