import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/provider_harness.dart';

void main() {
  testWidgets(
    'signed-out app launch redirects to login and password recovery',
    (tester) async {
      await tester.pumpWidget(
        buildParkdTestApp(dependencies: ParkdTestDependencies()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);

      expect(find.text('Forgot password?'), findsOneWidget);
      final router = GoRouter.of(tester.element(find.text('Welcome!')));
      router.go('/auth/forgot-password');
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/auth/forgot-password',
      );
      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Send Link'), findsOneWidget);
    },
  );
}
