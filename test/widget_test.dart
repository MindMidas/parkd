import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:parkd/app/app.dart';

void main() {
  testWidgets('App renders brand preview shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ParkdApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
