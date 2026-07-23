import 'package:flutter_test/flutter_test.dart';
import 'package:parkd/core/models/chat_message_row.dart';
import 'package:parkd/core/models/conversation_row.dart';
import 'package:parkd/core/models/message_delivery_status.dart';
import 'package:parkd/core/models/payment_method_row.dart';
import 'package:parkd/core/models/payment_record_status.dart';
import 'package:parkd/core/models/payment_row.dart';
import 'package:parkd/core/models/profile.dart';
import 'package:parkd/core/models/reservation_row.dart';
import 'package:parkd/core/models/reservation_status.dart';

void main() {
  group('database-backed models', () {
    test('profile chooses a safe display-name fallback order', () {
      expect(
        const Profile(id: '1', fullName: 'Test User').displayName,
        'Test User',
      );
      expect(const Profile(id: '1', username: 'tester').displayName, '@tester');
      expect(
        const Profile(id: '1', email: 'user@example.test').displayName,
        'user@example.test',
      );
      expect(const Profile(id: '1').displayName, 'User');
    });

    test('reservation and payment status parsing defaults to pending', () {
      final reservation = ReservationRow.fromJson({
        'id': 'reservation-1',
        'listing_id': 'listing-1',
        'driver_id': 'driver-1',
        'host_id': 'host-1',
        'start_time': '2026-07-21T14:00:00.000Z',
        'end_time': '2026-07-21T16:00:00.000Z',
        'total_price': 8,
        'service_fee': 0.28,
        'status': 'unknown',
      });
      final payment = PaymentRow.fromJson({
        'id': 'payment-1',
        'reservation_id': 'reservation-1',
        'amount': 8,
        'service_fee': 0.28,
        'status': 'unknown',
      });

      expect(reservation.status, ReservationStatus.pending);
      expect(payment.status, PaymentRecordStatus.pending);
      expect(reservation.totalPrice, 8.0);
      expect(payment.serviceFee, 0.28);
    });

    test(
      'message and conversation parsing tolerate optional database fields',
      () {
        final conversation = ConversationRow.fromJson({
          'id': 'conversation-1',
          'reservation_id': 'reservation-1',
          'host_id': 'host-1',
          'driver_id': 'driver-1',
        });
        final message = ChatMessageRow.fromJson({
          'id': 'message-1',
          'conversation_id': conversation.id,
          'sender_id': 'driver-1',
          'message': 'Hello',
          'status': 'not-a-status',
        });

        expect(conversation.isClosed, isFalse);
        expect(message.status, MessageDeliveryStatus.sent);
        expect(message.createdAt, isNull);
      },
    );

    test('saved payment methods default to non-default', () {
      final method = PaymentMethodRow.fromJson({
        'id': 'method-1',
        'user_id': 'driver-1',
        'brand': 'visa',
        'last4': '4242',
      });

      expect(method.isDefault, isFalse);
      expect(method.stripePaymentMethodId, isNull);
    });
  });
}
