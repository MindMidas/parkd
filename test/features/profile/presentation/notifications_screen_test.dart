import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/notification_row.dart';
import 'package:parkd/core/supabase/notifications_remote.dart';
import 'package:parkd/features/profile/presentation/account/notifications_screen.dart';
import 'package:parkd/features/profile/providers/notifications_providers.dart';

void main() {
  testWidgets('renders a minimal notification and pagination control', (
    tester,
  ) async {
    final row = NotificationRow(
      id: 'notification-1',
      userId: 'user-1',
      type: ParkdNotificationType.messageReceived,
      sourceEntityType: 'message',
      sourceEntityId: 'message-1',
      data: const {'hub': 'reservations', 'reservation_id': 'reservation-1'},
      isRead: false,
      createdAt: DateTime.utc(2026, 7, 20, 12),
    );
    final snapshot = NotificationFeedSnapshot(
      latest: [row],
      unread: const NotificationHubCounts(
        total: 1,
        reservations: 1,
        hosting: 0,
        account: 0,
        hostingBookings: 0,
        hostingReviews: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myNotificationFeedProvider.overrideWith(
            (ref) => Stream.value(snapshot),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('New message'), findsOneWidget);
    expect(
      find.text('Open the conversation to read the message.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('notifications_load_older')), findsOneWidget);
  });

  testWidgets('renders a useful empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myNotificationFeedProvider.overrideWith(
            (ref) => Stream.value(const NotificationFeedSnapshot.empty()),
          ),
        ],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet'), findsOneWidget);
    expect(
      find.text('Booking, review, and message updates appear here.'),
      findsOneWidget,
    );
  });
}
