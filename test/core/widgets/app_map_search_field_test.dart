import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/theme/app_colors.dart';
import 'package:parkd/core/widgets/app_map_search_card.dart';
import 'package:parkd/core/widgets/app_map_search_field.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('map search field uses solid card chrome', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        const AppMapSearchField(hintText: 'Search city or address…'),
      ),
    );

    expect(find.byType(AppMapSearchCard), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsNothing);
  });

  testWidgets('map search field keeps filter inside one card', (tester) async {
    var filterTaps = 0;
    await tester.pumpWidget(
      buildTestApp(
        AppMapSearchField(
          hintText: 'Search',
          showFilterButton: true,
          onFilterTap: () => filterTaps++,
        ),
      ),
    );

    expect(find.byType(AppMapSearchCard), findsOneWidget);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    expect(filterTaps, 1);
  });

  testWidgets('map search field centers loading spinner in suffix', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        const AppMapSearchField(
          hintText: 'Search',
          isLoading: true,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final fieldBox = tester.getSize(find.byType(TextField));
    final spinnerCenter = tester.getCenter(find.byType(CircularProgressIndicator));
    final fieldCenter = tester.getCenter(find.byType(TextField));
    expect((spinnerCenter.dy - fieldCenter.dy).abs(), lessThan(2));
    expect(spinnerCenter.dx, greaterThan(fieldBox.width * 0.5));
  });
}
