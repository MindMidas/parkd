import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/features/profile/providers/profile_providers.dart';

import '../../../helpers/fake_repositories.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/provider_harness.dart';

void main() {
  group('profile providers', () {
    test('load the signed-in profile, listings, and payment methods', () async {
      final profile = fixtureProfile();
      final listing = fixtureListing(hostId: profile.id);
      final paymentMethod = fixturePaymentMethod(userId: profile.id);
      final dependencies = ParkdTestDependencies(
        profiles: FakeProfileRepository([profile]),
        listings: FakeListingsRepository([listing]),
        paymentMethods: FakePaymentMethodsRepository([paymentMethod]),
      );
      final container = buildTestContainer(
        dependencies: dependencies,
        session: fixtureSession(userId: profile.id),
      );
      addTearDown(container.dispose);

      final loadedProfile = await container.read(currentProfileProvider.future);
      final loadedListings = await container.read(
        myListingsForCurrentUserProvider.future,
      );
      final loadedMethods = await container.read(
        paymentMethodsForCurrentUserProvider.future,
      );

      expect(loadedProfile?.id, profile.id);
      expect(loadedListings.map((row) => row.id), [listing.id]);
      expect(loadedMethods.map((row) => row.id), [paymentMethod.id]);
      expect(dependencies.profiles.requestedUserIds, [profile.id]);
      expect(dependencies.paymentMethods.requestedUserIds, [profile.id]);
    });

    test('family providers forward ids and expose seeded rows', () async {
      final listing = fixtureListing();
      final photo = fixtureListingPhoto();
      final weekly = fixtureWeeklyAvailability();
      final specific = fixtureSpecificAvailability();
      final listings = FakeListingsRepository([listing])
        ..photosByListing[listing.id] = [photo]
        ..weeklyByListing[listing.id] = [weekly]
        ..specificByListing[listing.id] = [specific];
      final dependencies = ParkdTestDependencies(listings: listings);
      final container = buildTestContainer(dependencies: dependencies);
      addTearDown(container.dispose);

      expect(
        (await container.read(listingByIdProvider(listing.id).future))?.id,
        listing.id,
      );
      expect(
        (await container.read(
          listingPhotosProvider(listing.id).future,
        )).single.id,
        photo.id,
      );
      expect(
        (await container.read(
          listingAvailabilityWeeklyProvider(listing.id).future,
        )).single.id,
        weekly.id,
      );
      expect(
        (await container.read(
          listingAvailabilitySpecificProvider(listing.id).future,
        )).single.id,
        specific.id,
      );
      expect(listings.requestedListingIds, [listing.id]);
    });

    test(
      'session-scoped providers return empty data when signed out',
      () async {
        final dependencies = ParkdTestDependencies(
          profiles: FakeProfileRepository([fixtureProfile()]),
          listings: FakeListingsRepository([
            fixtureListing(hostId: 'driver-1'),
          ]),
          paymentMethods: FakePaymentMethodsRepository([
            fixturePaymentMethod(),
          ]),
        );
        final container = buildTestContainer(dependencies: dependencies);
        addTearDown(container.dispose);

        expect(await container.read(currentProfileProvider.future), isNull);
        expect(
          await container.read(myListingsForCurrentUserProvider.future),
          isEmpty,
        );
        expect(
          await container.read(paymentMethodsForCurrentUserProvider.future),
          isEmpty,
        );
        expect(dependencies.profiles.requestedUserIds, isEmpty);
        expect(dependencies.paymentMethods.requestedUserIds, isEmpty);
      },
    );
  });
}
