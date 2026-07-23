import 'dart:math' as math;

/// Haversine distance between two latitude/longitude points, in kilometres.
double distanceKmBetween(
  double latitudeA,
  double longitudeA,
  double latitudeB,
  double longitudeB,
) {
  const radiansPerDegree = math.pi / 180;
  final haversine =
      0.5 -
      math.cos((latitudeB - latitudeA) * radiansPerDegree) / 2 +
      math.cos(latitudeA * radiansPerDegree) *
          math.cos(latitudeB * radiansPerDegree) *
          (1 - math.cos((longitudeB - longitudeA) * radiansPerDegree)) /
          2;
  return 12742 * math.asin(math.sqrt(haversine));
}

/// Parkd approximate area: ~250 m (~2–3 short blocks). Airbnb housing uses
/// ~½ mile; parking needs a shorter walk while still hiding the curb.
const double kApproximateListingAreaRadiusMeters = 250;

/// Small inner marker used with the shaded halo (Airbnb “circle in a circle”).
const double kApproximateListingCoreRadiusMeters = 22;

/// How far the public map marker is pushed from the rounded public coord so it
/// never sits on the driveway (Airbnb approximate ≠ pin-on-house).
const double kApproximateMarkerOffsetMeters = 110;

/// Privacy grid key used to cluster listings that would otherwise stack.
String approximateLocationCellKey(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}';
}

/// Deterministic Airbnb-style display center: same listing always lands in the
/// same offset spot, but not on the true curb.
({double latitude, double longitude}) obfuscateApproximateMapCenter({
  required String listingId,
  required double latitude,
  required double longitude,
  double offsetMeters = kApproximateMarkerOffsetMeters,
}) {
  final seed = listingId.hashCode;
  // Keep angle stable across runtimes; avoid 0..1 float noise.
  final angle = (seed & 0xffff) / 0xffff * 2 * math.pi;
  return _offsetLatLonMeters(
    latitude: latitude,
    longitude: longitude,
    eastMeters: offsetMeters * math.sin(angle),
    northMeters: offsetMeters * math.cos(angle),
  );
}

({double latitude, double longitude}) _offsetLatLonMeters({
  required double latitude,
  required double longitude,
  required double eastMeters,
  required double northMeters,
}) {
  const earthRadiusMeters = 6378137.0;
  final latRad = latitude * math.pi / 180;
  final metersPerDegreeLat = (math.pi / 180) * earthRadiusMeters;
  final cosLat = math.cos(latRad).abs().clamp(1e-6, 1.0);
  final metersPerDegreeLon = metersPerDegreeLat * cosLat;
  return (
    latitude: latitude + northMeters / metersPerDegreeLat,
    longitude: longitude + eastMeters / metersPerDegreeLon,
  );
}

/// Closed WGS84 ring (lng/lat) approximating a circle for Mapbox polygons.
List<List<double>> approximateListingAreaRing({
  required double latitude,
  required double longitude,
  double radiusMeters = kApproximateListingAreaRadiusMeters,
  int steps = 64,
}) {
  assert(steps >= 8);
  assert(radiusMeters > 0);
  final ring = <List<double>>[];
  for (var i = 0; i <= steps; i++) {
    final theta = 2 * math.pi * i / steps;
    final point = _offsetLatLonMeters(
      latitude: latitude,
      longitude: longitude,
      eastMeters: radiusMeters * math.sin(theta),
      northMeters: radiusMeters * math.cos(theta),
    );
    ring.add([point.longitude, point.latitude]);
  }
  return ring;
}
