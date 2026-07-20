import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/reservation_status.dart';
import 'package:parkd/features/reservations/providers/reservations_providers.dart';

import '../../../helpers/fake_repositories.dart';
import '../../../helpers/fixtures.dart';
import '../../../helpers/provider_harness.dart';

void main() {
  group('reservation providers', () {
    test(
      'split signed-in driver reservations into active and past lists',
      () async {
        final active = fixtureReservation();
        final past = fixtureReservation(
          id: 'reservation-past',
          status: ReservationStatus.completed,
        );
        final reservations = FakeReservationsRepository(
          reservations: [active, past],
        );
        final dependencies = ParkdTestDependencies(reservations: reservations);
        final container = buildTestContainer(
          dependencies: dependencies,
          session: fixtureSession(),
        );
        addTearDown(container.dispose);

        final activeRows = await container.read(
          driverActiveReservationsProvider.future,
        );
        final pastRows = await container.read(
          driverPastReservationsProvider.future,
        );

        expect(activeRows.map((row) => row.id), [active.id]);
        expect(pastRows.map((row) => row.id), [past.id]);
        expect(reservations.driverTripRequests, [
          (userId: 'driver-1', activeOnly: true),
          (userId: 'driver-1', activeOnly: false),
        ]);
      },
    );

    test(
      'joins driver trips to listings through the injected repository',
      () async {
        final reservation = fixtureReservation();
        final listing = fixtureListing(id: reservation.listingId);
        final reservations = FakeReservationsRepository(
          reservations: [reservation],
        );
        final listings = FakeListingsRepository([listing]);
        final dependencies = ParkdTestDependencies(
          reservations: reservations,
          listings: listings,
        );
        final container = buildTestContainer(
          dependencies: dependencies,
          session: fixtureSession(),
        );
        addTearDown(container.dispose);

        final trips = await container.read(driverActiveTripsProvider.future);

        expect(trips, hasLength(1));
        expect(trips.single.reservation.id, reservation.id);
        expect(trips.single.listing?.id, listing.id);
        expect(listings.requestedListingIds, [listing.id]);
      },
    );

    test('loads payment, inbox, and conversation messages by id', () async {
      final payment = fixturePayment();
      final conversation = fixtureConversation();
      final message = fixtureMessage();
      final dependencies = ParkdTestDependencies(
        reservations: FakeReservationsRepository(payments: [payment]),
        messaging: FakeMessagingRepository(
          conversations: [conversation],
          messages: [message],
        ),
      );
      final container = buildTestContainer(
        dependencies: dependencies,
        session: fixtureSession(),
      );
      addTearDown(container.dispose);

      final loadedPayment = await container.read(
        reservationPaymentProvider(payment.reservationId).future,
      );
      final inbox = await container.read(messagingInboxProvider.future);
      final subscription = container.listen(
        conversationMessagesProvider(conversation.id),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final messages = await container.read(
        conversationMessagesProvider(conversation.id).future,
      );

      expect(loadedPayment?.id, payment.id);
      expect(inbox.map((row) => row.id), [conversation.id]);
      expect(messages.map((row) => row.id), [message.id]);
    });

    test(
      'does not query account-scoped repositories while signed out',
      () async {
        final dependencies = ParkdTestDependencies();
        final container = buildTestContainer(dependencies: dependencies);
        addTearDown(container.dispose);

        expect(
          await container.read(driverActiveReservationsProvider.future),
          isEmpty,
        );
        expect(
          await container.read(hostActiveReservationsProvider.future),
          isEmpty,
        );
        expect(await container.read(messagingInboxProvider.future), isEmpty);
        expect(dependencies.reservations.driverTripRequests, isEmpty);
        expect(dependencies.reservations.hostTripRequests, isEmpty);
        expect(dependencies.messaging.inboxRequests, isEmpty);
      },
    );
  });
}
