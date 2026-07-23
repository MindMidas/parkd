import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/features/reservations/presentation/notification_conversation_route_screen.dart';

void main() {
  test('builds a reload-safe reservation message location', () {
    expect(
      reservationMessagesLocation('reservation-123'),
      '/reservations/reservation-123/messages',
    );
    expect(
      reservationMessagesLocation('reservation/with slash'),
      '/reservations/reservation%2Fwith%20slash/messages',
    );
  });
}
