import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/widgets/app_buttons.dart';

import '../../helpers/test_app.dart';

void main() {
  group('AppPrimaryButton', () {
    testWidgets('calls onPressed when enabled', (tester) async {
      var pressed = false;

      await tester.pumpWidget(
        buildTestApp(
          AppPrimaryButton(
            label: 'reserve now',
            onPressed: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.byType(FilledButton));

      expect(pressed, isTrue);
      expect(find.text('Reserve Now'), findsOneWidget);
    });

    testWidgets('shows progress and disables taps while loading', (
      tester,
    ) async {
      var pressed = false;

      await tester.pumpWidget(
        buildTestApp(
          AppPrimaryButton(
            label: 'pay',
            loading: true,
            onPressed: () => pressed = true,
          ),
        ),
      );

      await tester.tap(find.byType(FilledButton));

      expect(pressed, isFalse);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('AppSecondaryButton', () {
    testWidgets('renders destructive filled secondary actions', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          AppSecondaryButton(
            label: 'remove card',
            destructive: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.text('Remove Card'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  });
}
