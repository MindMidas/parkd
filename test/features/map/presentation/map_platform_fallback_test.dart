import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/listing.dart';
import 'package:parkd/features/map/presentation/map_platform_fallback.dart';

import '../../../helpers/test_app.dart';

void main() {
  Listing listing({
    required String id,
    required String address,
    required double latitude,
    required double longitude,
    double? hourlyPrice,
  }) {
    return Listing(
      id: id,
      hostId: 'host-$id',
      address: address,
      city: 'Guelph',
      country: 'Canada',
      latitude: latitude,
      longitude: longitude,
      isActive: true,
      isPublished: true,
      isApproximateLocation: true,
      minHourlyPrice: hourlyPrice,
    );
  }

  test('sortListingsNear returns nearest approximate listing first', () {
    final far = listing(
      id: 'far',
      address: 'Far area',
      latitude: 44,
      longitude: -81,
    );
    final near = listing(
      id: 'near',
      address: 'Near area',
      latitude: 43.51,
      longitude: -80.21,
    );

    final input = [far, near];
    final sorted = sortListingsNear(
      listings: input,
      latitude: 43.5,
      longitude: -80.2,
    );

    expect(sorted.map((value) => value.id), ['near', 'far']);
    expect(sorted, isNot(same(input)));
  });

  testWidgets('fallback keeps search, listings, prices, and taps functional', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? tappedId;
    final nearby = listing(
      id: 'nearby',
      address: 'Downtown parking area',
      latitude: 43.54,
      longitude: -80.25,
      hourlyPrice: 5,
    );

    await tester.pumpWidget(
      buildTestApp(
        MapPlatformFallback(
          searchPanel: const SizedBox(
            key: Key('existing-address-search'),
            height: 52,
          ),
          listings: [nearby],
          selectedAreaLabel: 'Downtown Guelph, Ontario',
          onListingTap: (value) => tappedId = value.id,
          onRetry: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('existing-address-search')), findsOneWidget);
    expect(find.text('Parking near Downtown Guelph'), findsOneWidget);
    expect(find.text('Guelph, Canada'), findsOneWidget);
    expect(find.text(r'From $5/hr'), findsOneWidget);
    expect(find.text('Approximate location'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('fallback-listing-nearby')));
    expect(tappedId, 'nearby');
  });

  testWidgets('fallback exposes a recoverable load error', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      buildTestApp(
        MapPlatformFallback(
          searchPanel: const SizedBox(height: 52),
          listings: const [],
          hasError: true,
          onListingTap: (_) {},
          onRetry: () => retries += 1,
        ),
      ),
    );

    expect(find.text('Parking spots could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
