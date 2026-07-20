import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/notification_row.dart';
import 'package:parkd/core/supabase/notifications_remote.dart';
import 'package:parkd/features/profile/providers/notifications_providers.dart';

NotificationRow _row({
  required String id,
  required ParkdNotificationType type,
  required NotificationHub hub,
  bool isRead = false,
}) {
  return NotificationRow(
    id: id,
    userId: 'user-1',
    type: type,
    sourceEntityType: type == ParkdNotificationType.messageReceived
        ? 'message'
        : type == ParkdNotificationType.reviewReceived
        ? 'review'
        : 'reservation',
    sourceEntityId: 'source-$id',
    data: {'hub': hub.name, 'reservation_id': 'reservation-1'},
    isRead: isRead,
    createdAt: DateTime.utc(2026, 7, 20),
  );
}

void main() {
  test('exposes exact hub totals and categorizes latest menu badges', () async {
    final latest = [
      _row(
        id: 'booking',
        type: ParkdNotificationType.reservationConfirmed,
        hub: NotificationHub.hosting,
      ),
      _row(
        id: 'review',
        type: ParkdNotificationType.reviewReceived,
        hub: NotificationHub.hosting,
      ),
      _row(
        id: 'message',
        type: ParkdNotificationType.messageReceived,
        hub: NotificationHub.reservations,
      ),
      _row(
        id: 'read-message',
        type: ParkdNotificationType.messageReceived,
        hub: NotificationHub.reservations,
        isRead: true,
      ),
    ];
    final snapshot = NotificationFeedSnapshot(
      latest: latest,
      unread: const NotificationHubCounts(
        total: 8,
        reservations: 3,
        hosting: 4,
        account: 1,
        hostingBookings: 2,
        hostingReviews: 2,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        myNotificationFeedProvider.overrideWith(
          (ref) => Stream.value(snapshot),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      myNotificationFeedProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.read(myNotificationFeedProvider.future);

    expect(container.read(myNotificationHubCountsProvider).total, 8);
    expect(container.read(hostingBookingNotificationsCountProvider), 2);
    expect(container.read(hostingReviewNotificationsCountProvider), 2);
    expect(container.read(reservationNotificationsCountProvider), 3);
  });
}
