import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import 'map_constants.dart';

/// Centers [map] on the user when permission and services allow; otherwise on
/// the default map center (Guelph). Matches the simple “try GPS first” behavior
/// used for create-listing / embedded maps (no first-run dialog)
Future<void> tryCenterMapOnUserLocation(MapboxMap map) async {
  var perm = await geo.Geolocator.checkPermission();
  if (perm == geo.LocationPermission.denied) {
    perm = await geo.Geolocator.requestPermission();
  }
  final granted =
      perm == geo.LocationPermission.whileInUse ||
      perm == geo.LocationPermission.always;
  if (!granted) {
    await configureMapLocationPuck(map, enabled: false);
    await flyMapToLatLon(
      map,
      latitude: MapConstants.defaultLatitude,
      longitude: MapConstants.defaultLongitude,
      zoom: MapConstants.defaultZoom,
    );
    return;
  }

  final serviceOn = await geo.Geolocator.isLocationServiceEnabled();
  if (!serviceOn) {
    await configureMapLocationPuck(map, enabled: false);
    await flyMapToLatLon(
      map,
      latitude: MapConstants.defaultLatitude,
      longitude: MapConstants.defaultLongitude,
      zoom: MapConstants.defaultZoom,
    );
    return;
  }

  try {
    final pos = await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.medium,
      ),
    );
    await configureMapLocationPuck(map, enabled: true);
    await flyMapToLatLon(
      map,
      latitude: pos.latitude,
      longitude: pos.longitude,
      zoom: MapConstants.defaultZoom,
    );
  } catch (_) {
    await configureMapLocationPuck(map, enabled: false);
    await flyMapToLatLon(
      map,
      latitude: MapConstants.defaultLatitude,
      longitude: MapConstants.defaultLongitude,
      zoom: MapConstants.defaultZoom,
    );
  }
}

/// Opens this app’s Settings page (Location, etc.). On iOS 18+, falls back from
/// `App-prefs:<bundle id>` to [Geolocator.openAppSettings] if needed
Future<void> openAppLocationSettings() async {
  if (Platform.isIOS) {
    try {
      final bundleId = (await PackageInfo.fromPlatform()).packageName;
      final uri = Uri.parse('App-prefs:$bundleId');
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // Fall through
    }
  }
  await geo.Geolocator.openAppSettings();
}

Future<void> configureMapLocationPuck(
  MapboxMap map, {
  required bool enabled,
}) async {
  if (!enabled) {
    await map.location.updateSettings(
      LocationComponentSettings(enabled: false),
    );
    return;
  }
  await map.location.updateSettings(
    LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
      pulsingColor: AppColors.primaryBlue
          .withValues(alpha: 0x66 / 255)
          .toARGB32(),
      showAccuracyRing: true,
      accuracyRingColor: AppColors.primaryBlue
          .withValues(alpha: 0x33 / 255)
          .toARGB32(),
      accuracyRingBorderColor: AppColors.primaryBlue
          .withValues(alpha: 0x59 / 255)
          .toARGB32(),
      puckBearingEnabled: true,
      puckBearing: PuckBearing.COURSE,
      locationPuck: LocationPuck(locationPuck2D: DefaultLocationPuck2D()),
    ),
  );
}

/// Requests location permission (when-in-use) and returns the current fix, or
/// `null` if denied / unavailable
Future<geo.Position?> getCurrentUserPositionIfAllowed() async {
  var perm = await geo.Geolocator.checkPermission();
  if (perm == geo.LocationPermission.denied) {
    perm = await geo.Geolocator.requestPermission();
  }
  if (perm == geo.LocationPermission.denied ||
      perm == geo.LocationPermission.deniedForever) {
    return null;
  }
  final enabled = await geo.Geolocator.isLocationServiceEnabled();
  if (!enabled) return null;
  try {
    return await geo.Geolocator.getCurrentPosition(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.medium,
      ),
    );
  } catch (_) {
    return null;
  }
}

/// Animates the map to [latitude] / [longitude] (WGS84)
Future<void> flyMapToLatLon(
  MapboxMap map, {
  required double latitude,
  required double longitude,
  double zoom = MapConstants.defaultZoom,
}) {
  return map.flyTo(
    CameraOptions(
      center: Point(coordinates: Position(longitude, latitude)),
      zoom: zoom,
    ),
    null,
  );
}
