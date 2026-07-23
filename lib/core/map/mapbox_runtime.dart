import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Whether Parkd can use Mapbox's native platform view on this platform.
///
/// `mapbox_maps_flutter` supports Android and iOS. Web and desktop builds use
/// Parkd's responsive, non-interactive map fallback instead.
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

/// Configures Mapbox only when the current runtime supports its native view.
///
/// Keeping [tokenProvider] lazy is important: web and desktop builds do
/// not require a Mapbox token and never call [MapboxOptions.setAccessToken].
bool initializeNativeMapbox({
  required String Function() tokenProvider,
  @visibleForTesting void Function(String token)? accessTokenSetter,
}) {
  if (!supportsNativeMapboxMaps) return false;
  final token = tokenProvider();
  (accessTokenSetter ?? MapboxOptions.setAccessToken)(token);
  return true;
}
