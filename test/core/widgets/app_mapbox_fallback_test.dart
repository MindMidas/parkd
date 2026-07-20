import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:parkd/core/widgets/app_mapbox_preview.dart';
import 'package:parkd/features/map/presentation/map.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets(
    'embedded map preview uses a static unsupported-platform view',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const SizedBox(
            width: 320,
            child: AppMapboxPreview(latitude: 43.5, longitude: -80.2),
          ),
        ),
      );

      expect(find.byKey(const Key('app-static-map-preview')), findsOneWidget);
      expect(find.text('Parking area preview'), findsOneWidget);
      expect(find.byType(MapWidget), findsNothing);
    },
    variant: TargetPlatformVariant(const {TargetPlatform.macOS}),
  );

  testWidgets(
    'full map view never creates MapWidget on desktop',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(const SizedBox(width: 400, height: 300, child: MapView())),
      );

      expect(find.byKey(const Key('app-static-map-preview')), findsOneWidget);
      expect(find.text('Interactive map available on mobile'), findsOneWidget);
      expect(find.byType(MapWidget), findsNothing);
    },
    variant: TargetPlatformVariant(const {TargetPlatform.macOS}),
  );
}
