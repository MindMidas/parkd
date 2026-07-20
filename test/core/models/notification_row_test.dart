import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/notification_row.dart';

void main() {
  group('NotificationRow', () {
    test('parses a privacy-minimized message event', () {
      final row = NotificationRow.fromJson({
        'id': 'notification-1',
        'user_id': 'host-1',
        'actor_user_id': 'driver-1',
        'type': 'message_received',
        'source_entity_type': 'message',
        'source_entity_id': 'message-1',
        'data_json': {
          'reservation_id': 'reservation-1',
          'conversation_id': 'conversation-1',
          'hub': 'hosting',
        },
        'is_read': false,
        'read_at': null,
        'created_at': '2026-07-20T12:00:00Z',
      });

      expect(row.type, ParkdNotificationType.messageReceived);
      expect(row.hub, NotificationHub.hosting);
      expect(row.reservationId, 'reservation-1');
      expect(row.title, 'New message');
      expect(row.body, isNot(contains('private')));
      expect(row.createdAt, DateTime.utc(2026, 7, 20, 12));
    });

    test('uses a reservation source id as the route fallback', () {
      final row = NotificationRow.fromJson({
        'id': 'notification-2',
        'user_id': 'host-1',
        'type': 'reservation_confirmed',
        'source_entity_type': 'reservation',
        'source_entity_id': 'reservation-2',
        'data_json': const {'hub': 'hosting'},
        'is_read': true,
        'read_at': '2026-07-20T12:01:00Z',
        'created_at': '2026-07-20T12:00:00Z',
      });

      expect(row.reservationId, 'reservation-2');
      expect(row.isRead, isTrue);
    });

    test('rejects unknown event types', () {
      expect(
        () => NotificationRow.fromJson({
          'id': 'notification-3',
          'user_id': 'host-1',
          'type': 'arbitrary_client_event',
          'source_entity_type': 'message',
          'source_entity_id': 'message-3',
          'data_json': const {},
          'is_read': false,
          'created_at': '2026-07-20T12:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });
}
