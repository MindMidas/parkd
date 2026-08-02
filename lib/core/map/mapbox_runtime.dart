import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Native Mapbox is only supported on Android and iOS.
bool get supportsNativeMapboxMaps =>
    supportsNativeMapboxMapsFor(isWeb: kIsWeb, platform: defaultTargetPlatform);

@visibleForTesting
bool supportsNativeMapboxMapsFor({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return false;
  return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
}

// Set the access token only when the native SDK is available.
bool initializeNativeMapbox({
  required String Function() tokenProvider,
  @visibleForTesting void Function(String token)? accessTokenSetter,
}) {
  if (!supportsNativeMapboxMaps) return false;
  final token = tokenProvider();
  (accessTokenSetter ?? MapboxOptions.setAccessToken)(token);
  return true;
}
