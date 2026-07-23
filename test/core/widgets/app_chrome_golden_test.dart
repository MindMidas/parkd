import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/theme/app_theme.dart';
import 'package:parkd/core/widgets/app_buttons.dart';
import 'package:parkd/core/widgets/app_modal_sheet.dart';
import 'package:parkd/core/widgets/app_nav_tile.dart';
import 'package:parkd/core/widgets/app_outcome_view.dart';
import 'package:parkd/core/widgets/app_page_status.dart';
import 'package:parkd/core/widgets/app_sticky_footer.dart';
import 'package:parkd/core/widgets/app_top_bar.dart';

Widget _goldenSurface(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: 430, height: 900, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('golden AppPageStatus empty', (tester) async {
    await tester.pumpWidget(
      _goldenSurface(
        const AppPageStatus.empty(
          title: 'No listings yet',
          message: 'Publish a spot to get started.',
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/app_page_status_empty.png'),
    );
  });

  testWidgets('golden AppPageStatus error', (tester) async {
    await tester.pumpWidget(
      _goldenSurface(
        AppPageStatus.error(actionLabel: 'Try again', onAction: () {}),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/app_page_status_error.png'),
    );
  });

  testWidgets('golden AppModalSheet chrome', (tester) async {
    await tester.pumpWidget(
      _goldenSurface(
        const Align(
          alignment: Alignment.bottomCenter,
          child: AppModalSheet(
            child: Text('Filter options'),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/app_modal_sheet.png'),
    );
  });

  testWidgets('golden AppPrimaryButton', (tester) async {
    await tester.pumpWidget(
      _goldenSurface(
        const Padding(
          padding: EdgeInsets.all(24),
          child: AppPrimaryButton(label: 'Make a reservation', onPressed: null),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/app_primary_button.png'),
    );
  });

  testWidgets('golden AppNavTile', (tester) async {
    await tester.pumpWidget(
      _goldenSurface(
        AppNavTile(
          label: 'Manage listings',
          icon: Icons.local_parking_rounded,
          subtitle: 'Edit availability and photos',
          onTap: () {},
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/app_nav_tile.png'),
    );
  });

  testWidgets('golden AppOutcomeView failure', (tester) async {
    await tester.pumpWidget(
      _goldenSurface(
        AppOutcomeView(
          kind: AppOutcomeKind.failure,
          message: 'Please try again.',
          onClose: () {},
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/app_outcome_failure.png'),
    );
  });

  testWidgets('golden AppTopBar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          appBar: AppTopBar(title: 'Hosting', showBack: true),
          body: SizedBox.expand(),
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/app_top_bar.png'),
    );
  });

  testWidgets('golden AppStickyFooter', (tester) async {
    await tester.pumpWidget(
      _goldenSurface(
        const Column(
          children: [
            Expanded(child: SizedBox.shrink()),
            AppStickyFooter(
              child: AppPrimaryButton(label: 'Continue', onPressed: null),
            ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../goldens/app_sticky_footer.png'),
    );
  });
}
