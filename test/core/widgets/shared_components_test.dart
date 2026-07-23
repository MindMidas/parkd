import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/widgets/app_bottom_nav.dart';
import 'package:parkd/core/widgets/app_confirm_dialog.dart';
import 'package:parkd/core/widgets/app_outcome_view.dart';
import 'package:parkd/core/widgets/app_notification_badge.dart';
import 'package:parkd/core/widgets/app_payment_method_pill.dart';
import 'package:parkd/core/widgets/app_search_field.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('search field reports user input', (tester) async {
    String? query;
    await tester.pumpWidget(
      buildTestApp(AppSearchField(onChanged: (value) => query = value)),
    );

    await tester.enterText(find.byType(TextField), 'downtown');

    expect(query, 'downtown');
  });

  testWidgets('payment pill reports taps and selected state', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildTestApp(
        AppPaymentMethodPill(
          brand: 'Visa',
          lastFour: '4242',
          selected: true,
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Visa'));

    expect(tapped, isTrue);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text(' •••• 4242'), findsOneWidget);
  });

  testWidgets('confirmation dialog exposes cancel and destructive actions', (
    tester,
  ) async {
    var result = '';
    await tester.pumpWidget(
      buildTestApp(
        AppConfirmDialog(
          title: 'Delete listing?',
          message: 'This cannot be undone.',
          confirmLabel: 'Delete',
          confirmDestructive: true,
          onCancel: () => result = 'cancel',
          onConfirm: () => result = 'confirm',
        ),
      ),
    );

    await tester.tap(find.text('Delete'));

    expect(result, 'confirm');
    expect(find.text('This cannot be undone.'), findsOneWidget);
  });

  testWidgets('outcome view renders failure copy and closes', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      buildTestApp(
        AppOutcomeView(
          kind: AppOutcomeKind.failure,
          message: 'Please try again.',
          onClose: () => closed = true,
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    await tester.tap(find.text('Close'));
    expect(closed, isTrue);
  });

  testWidgets('bottom navigation exposes all destinations and selection', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      buildTestApp(
        AppBottomNav(
          selectedIndex: 1,
          reservationsBadgeCount: 4,
          onDestinationSelected: (index) => selected = index,
        ),
      ),
    );

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Reservations'), findsOneWidget);
    expect(find.text('Hosting'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    await tester.tap(find.text('Account'));
    expect(selected, 3);
  });

  testWidgets('re-tapping the selected tab still reports the index', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      buildTestApp(
        AppBottomNav(
          selectedIndex: 2,
          onDestinationSelected: (index) => selected = index,
        ),
      ),
    );

    await tester.tap(find.text('Hosting'));
    expect(selected, 2);
  });

  testWidgets(
    'notification badge caps visual text and keeps the true semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        buildTestApp(const AppNotificationBadge(count: 120)),
      );

      expect(find.text('99+'), findsOneWidget);
      expect(find.bySemanticsLabel('120 unread notifications'), findsOneWidget);
      semantics.dispose();
    },
  );
}
