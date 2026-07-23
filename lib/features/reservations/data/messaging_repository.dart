import '../../../core/models/chat_message_row.dart';
import '../../../core/models/conversation_row.dart';
import '../../../core/models/host_listing_booking_thread.dart';

/// Thread per reservation
abstract class MessagingRepository {
  Future<ConversationRow> ensureThread(String reservationId);

  Future<List<ConversationRow>> inboxForUser(String userId);

  /// Host hub: bookings at [listingId] where you are [hostId], with optional chat + preview
  Future<List<HostListingBookingThread>> listHostListingThreads({
    required String hostId,
    required String listingId,
    required bool activeOnly,
  });

  Future<List<ChatMessageRow>> messages(String conversationId);

  Stream<List<ChatMessageRow>> watchMessages(String conversationId);

  Future<ChatMessageRow> send({
    required String conversationId,
    required String senderId,
    required String text,
  });

  Future<void> markRead(String messageId);
}
