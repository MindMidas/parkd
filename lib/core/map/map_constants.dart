// def map camera: Guelph, Ontario, Canada (lat / lon in WGS84)
abstract final class MapConstants {
  static const double defaultLatitude = 43.5448;
  static const double defaultLongitude = -80.2482;
  static const double defaultZoom = 14;
}

// bottom offset for map "my location"
const double kParkdMapRecenterFabBottomOffset = 16;

// tap target size of re-center FAB
const double kParkdMapRecenterFabSize = 44;

// gap between recenter FAB and compass above
const double kParkdMapCompassGapAboveFab = 10;
