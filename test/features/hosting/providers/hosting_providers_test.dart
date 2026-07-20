import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/features/hosting/providers/hosting_providers.dart';

import '../../../helpers/fake_repositories.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/provider_harness.dart';

void main() {
  group('hosting providers', () {
    test('loads earnings for the signed-in host', () async {
      final earnings = fixtureHostEarnings();
      final repository = FakeHostEarningsRepository(earnings: [earnings]);
      final dependencies = ParkdTestDependencies(earnings: repository);
      final container = buildTestContainer(
        dependencies: dependencies,
        session: fixtureSession(userId: earnings.hostId),
      );
      addTearDown(container.dispose);

      final rows = await container.read(
        hostEarningsForCurrentUserProvider.future,
      );

      expect(rows.map((row) => row.grossEarnings), [48]);
      expect(repository.requestedHostIds, [earnings.hostId]);
    });

    test('returns no earnings without an authenticated user', () async {
      final repository = FakeHostEarningsRepository(
        earnings: [fixtureHostEarnings()],
      );
      final dependencies = ParkdTestDependencies(earnings: repository);
      final container = buildTestContainer(dependencies: dependencies);
      addTearDown(container.dispose);

      expect(
        await container.read(hostEarningsForCurrentUserProvider.future),
        isEmpty,
      );
      expect(repository.requestedHostIds, isEmpty);
    });
  });
}
