import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/provider_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed-out launch redirects to auth and routes to recovery', (
    tester,
  ) async {
    // All backend providers are in-memory overrides. This smoke test is safe in
    // forks and CI because it never reads credentials or reaches the network.
    await tester.pumpWidget(
      buildParkdTestApp(dependencies: ParkdTestDependencies()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);

    expect(find.text('Forgot password?'), findsOneWidget);
    GoRouter.of(
      tester.element(find.text('Welcome!')),
    ).go('/auth/forgot-password');
    await tester.pumpAndSettle();

    expect(find.text('Reset Password'), findsOneWidget);
    expect(find.text('Send Link'), findsOneWidget);
  });
}
