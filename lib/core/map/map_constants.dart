// Default map camera: Guelph, Ontario, Canada (lat / lon in WGS84)
abstract final class MapConstants {
  static const double defaultLatitude = 43.5448;
  static const double defaultLongitude = -80.2482;
  static const double defaultZoom = 12.5;
}

// Bottom offset for the map location FAB.
const double kParkdMapRecenterFabBottomOffset = 16;

// Tap target size of the re-center FAB (for compass clearance)
const double kParkdMapRecenterFabSize = 44;

// Shared trailing inset so Mapbox compass + Flutter recenter share one column.
const double kParkdMapTrailingControlInset = 16;

// Gap between re-center FAB and the compass above it
const double kParkdMapCompassGapAboveFab = 10;
