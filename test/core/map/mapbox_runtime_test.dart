import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/map/mapbox_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('native Mapbox support is limited to Android and iOS', () {
    expect(
      supportsNativeMapboxMapsFor(
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      supportsNativeMapboxMapsFor(isWeb: false, platform: TargetPlatform.iOS),
      isTrue,
    );
    expect(
      supportsNativeMapboxMapsFor(
        isWeb: true,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
    expect(
      supportsNativeMapboxMapsFor(isWeb: false, platform: TargetPlatform.macOS),
      isFalse,
    );
    expect(
      supportsNativeMapboxMapsFor(
        isWeb: false,
        platform: TargetPlatform.windows,
      ),
      isFalse,
    );
    expect(
      supportsNativeMapboxMapsFor(isWeb: false, platform: TargetPlatform.linux),
      isFalse,
    );
  });

  test('unsupported platforms do not load or set a Mapbox token', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    var tokenWasLoaded = false;
    var tokenWasSet = false;

    final initialized = initializeNativeMapbox(
      tokenProvider: () {
        tokenWasLoaded = true;
        return 'pk.test';
      },
      accessTokenSetter: (_) => tokenWasSet = true,
    );

    expect(initialized, isFalse);
    expect(tokenWasLoaded, isFalse);
    expect(tokenWasSet, isFalse);
  });

  test('a supported native platform loads and sets its token once', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var loadCount = 0;
    final setTokens = <String>[];

    final initialized = initializeNativeMapbox(
      tokenProvider: () {
        loadCount += 1;
        return 'pk.test-native';
      },
      accessTokenSetter: setTokens.add,
    );

    expect(initialized, isTrue);
    expect(loadCount, 1);
    expect(setTokens, ['pk.test-native']);
  });
}
