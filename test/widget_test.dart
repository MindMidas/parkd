import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:parkd/app/app.dart';

void main() {
  testWidgets('App renders brand preview shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ParkdApp()));
    await tester.pumpAndSettle();

    expect(find.text('Parkd UI Component Preview'), findsOneWidget);
  });
}
