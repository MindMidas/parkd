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

import '../../helpers/test_app.dart';

void main() {
  testWidgets('AppPageStatus loading shows progress', (tester) async {
    await tester.pumpWidget(buildTestApp(const AppPageStatus.loading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppPageStatus empty shows title and message', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const AppPageStatus.empty(
          title: 'No listings yet',
          message: 'Publish a spot to get started.',
        ),
      ),
    );
    expect(find.text('No listings yet'), findsOneWidget);
    expect(find.text('Publish a spot to get started.'), findsOneWidget);
  });

  testWidgets('AppPageStatus error exposes retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      buildTestApp(
        AppPageStatus.error(
          actionLabel: 'Try again',
          onAction: () => retried = true,
        ),
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('AppModalSheet shows grabber and child', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const AppModalSheet(
          child: Text('Sheet body'),
        ),
      ),
    );
    expect(find.text('Sheet body'), findsOneWidget);
  });

  testWidgets('AppStickyFooter renders child', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const AppStickyFooter(child: Text('Continue')),
      ),
    );
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('AppNavTile shows label and responds to tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildTestApp(
        AppNavTile(
          label: 'Manage listings',
          icon: Icons.local_parking_rounded,
          onTap: () => tapped = true,
        ),
      ),
    );
    await tester.tap(find.text('Manage listings'));
    expect(tapped, isTrue);
  });

  testWidgets('AppTopBar shows title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          appBar: AppTopBar(title: 'Hosting', showBack: false),
          body: SizedBox.shrink(),
        ),
      ),
    );
    expect(find.text('Hosting'), findsOneWidget);
  });

  testWidgets('AppOutcomeView success copy', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        AppOutcomeView(
          kind: AppOutcomeKind.success,
          message: 'Listing published.',
          onClose: () {},
        ),
      ),
    );
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Listing published.'), findsOneWidget);
  });

  testWidgets('AppPrimaryButton disabled still shows label', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const AppPrimaryButton(label: 'Reserve', onPressed: null),
      ),
    );
    expect(find.text('Reserve'), findsOneWidget);
  });
}
