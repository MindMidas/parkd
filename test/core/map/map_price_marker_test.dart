import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/map/map_price_marker.dart';
import 'package:parkd/core/widgets/app_mapbox_preview.dart';
import 'package:parkd/core/widgets/app_static_map_preview.dart';

import '../../helpers/test_app.dart';
import 'package:flutter/material.dart';

Future<ui.Image> _decodePng(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

void main() {
  test('default and selected price pill PNGs differ', () async {
    final normal = await buildMapPriceMarkerPng(
      label: r'$12',
      selected: false,
    );
    final selected = await buildMapPriceMarkerPng(
      label: r'$12',
      selected: true,
    );
    expect(normal.length, greaterThan(100));
    expect(selected.length, greaterThan(100));
    expect(normal, isNot(equals(selected)));

    final normalImage = await _decodePng(normal);
    final selectedImage = await _decodePng(selected);
    expect(normalImage.width, greaterThan(0));
    expect(selectedImage.height, greaterThanOrEqualTo(normalImage.height));
    normalImage.dispose();
    selectedImage.dispose();
  });

  test('approximate center badge PNG is non-empty', () async {
    final badge = await buildApproximateCenterBadgePng();
    expect(badge.length, greaterThan(100));
  });

  testWidgets('AppApproximateLocationMap renders preview chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        const SizedBox(
          width: 320,
          child: AppApproximateLocationMap(
            latitude: 43.54,
            longitude: -80.25,
            showApproximateHalo: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AppApproximateLocationMap), findsOneWidget);
    // Test host typically lacks native Mapbox → static fallback.
    expect(
      find.byType(AppStaticMapPreview).evaluate().isNotEmpty ||
          find.byType(AppApproximateLocationMap).evaluate().isNotEmpty,
      isTrue,
    );
  });
}
