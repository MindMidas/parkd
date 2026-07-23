import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/features/map/presentation/map_filters_sheet.dart';
import 'package:parkd/features/map/providers/map_providers.dart';

void main() {
  testWidgets('restored sheet exposes proximity and availability controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMapFiltersSheet(context),
                child: const Text('Open filters'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open filters'));
    await tester.pumpAndSettle();

    expect(find.text('Near my location'), findsOneWidget);
    expect(find.text('Filter by calendar & time'), findsOneWidget);

    await tester.tap(find.text('Near my location'));
    await tester.pump();
    expect(container.read(mapFiltersProvider).proximityEnabled, isTrue);
    expect(find.text('Proximity · 10 km'), findsOneWidget);

    await tester.ensureVisible(find.text('Filter by calendar & time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter by calendar & time'));
    await tester.pump();
    expect(
      container.read(mapFiltersProvider).availabilityFilterEnabled,
      isTrue,
    );
    expect(find.text('Dates & times'), findsOneWidget);
    expect(
      find.text('Select at least one day to apply this filter.'),
      findsOneWidget,
    );
  });
}
