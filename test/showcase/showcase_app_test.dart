import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/showcase/showcase_app.dart';

void main() {
  testWidgets('showcase opens without credentials and changes tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const ParkdShowcaseApp());
    await tester.pumpAndSettle();

    expect(find.text('Find parking'), findsOneWidget);
    expect(find.text('Available spots'), findsOneWidget);

    await tester.tap(find.text('Hosting'));
    await tester.pumpAndSettle();

    expect(find.text('This month'), findsOneWidget);
    expect(find.text('\$186.50'), findsOneWidget);
  });

  testWidgets('search filters local sample listings', (tester) async {
    await tester.pumpWidget(const ParkdShowcaseApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('showcase-search')), 'campus');
    await tester.pump();

    expect(find.text('Covered spot near campus'), findsOneWidget);
    expect(find.text('Quiet downtown driveway'), findsNothing);
  });

  testWidgets('simulated booking adds a local reservation', (tester) async {
    await tester.pumpWidget(const ParkdShowcaseApp());
    await tester.pumpAndSettle();

    final listing = find.text('Quiet downtown driveway');
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(listing);
    await tester.pumpAndSettle();
    final reserveButton = find.byKey(const Key('showcase-reserve-button'));
    await tester.ensureVisible(reserveButton);
    await tester.tap(reserveButton);
    await tester.pumpAndSettle();

    expect(find.text('Reservations'), findsWidgets);
    expect(find.text('Just added'), findsOneWidget);
    expect(find.text('PKD-DEMO-NEW'), findsOneWidget);
  });
}
