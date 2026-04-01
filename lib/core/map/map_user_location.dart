import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import 'map_constants.dart';

// Move map to user location if allowed, else default Guelph view.
Future<void> tryCenterMapOnUserLocation(MapboxMap map) async {
  var perm = await geo.Geolocator.checkPermission();
  if (perm == geo.LocationPermission.denied) {
    perm = await geo.Geolocator.requestPermission();
  }
  final granted = perm == geo.LocationPermission.whileInUse ||
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

// System settings for location; iOS tries app prefs URL first then Geolocator fallback.
Future<void> openAppLocationSettings() async {
  if (Platform.isIOS) {
    try {
      final bundleId = (await PackageInfo.fromPlatform()).packageName;
      final uri = Uri.parse('App-prefs:$bundleId');
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
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
      pulsingColor:
          AppColors.primaryBlue.withValues(alpha: 0x66 / 255).toARGB32(),
      showAccuracyRing: true,
      accuracyRingColor:
          AppColors.primaryBlue.withValues(alpha: 0x33 / 255).toARGB32(),
      accuracyRingBorderColor:
          AppColors.primaryBlue.withValues(alpha: 0x59 / 255).toARGB32(),
      puckBearingEnabled: true,
      puckBearing: PuckBearing.COURSE,
      locationPuck: LocationPuck(
        locationPuck2D: DefaultLocationPuck2D(),
      ),
    ),
  );
}

// Ask for when-in-use location and return a fix, or null if blocked or off.
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

// Fly the map camera to a lat lng.
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
