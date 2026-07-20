import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/conversations_remote.dart';
import '../../../core/supabase/reservations_remote.dart';
import '../../../core/models/chat_message_row.dart';
import '../../../core/models/conversation_row.dart';
import '../../../core/models/host_listing_booking_thread.dart';
import 'messaging_repository.dart';

class SupabaseMessagingRepository implements MessagingRepository {
  SupabaseMessagingRepository(SupabaseClient client)
    : _remote = ConversationsRemote(client),
      _reservations = ReservationsRemote(client);

  final ConversationsRemote _remote;
  final ReservationsRemote _reservations;

  @override
  Future<ConversationRow> ensureThread(String reservationId) =>
      _remote.ensureConversation(reservationId);

  @override
  Future<List<ConversationRow>> inboxForUser(String userId) =>
      _remote.listForUser(userId);

  @override
  Future<List<HostListingBookingThread>> listHostListingThreads({
    required String hostId,
    required String listingId,
    required bool activeOnly,
  }) async {
    final reservations = await _reservations.fetchForHostListing(
      hostId,
      listingId,
      activeOnly: activeOnly,
    );
    if (reservations.isEmpty) return [];
    final resIds = reservations.map((r) => r.id).toList();
    final conversations = await _remote.listByReservationIds(resIds);
    final byResId = {for (final c in conversations) c.reservationId: c};
    final convIds = conversations.map((c) => c.id).toList();
    final previews = await _remote.lastMessagePreviewByConversationId(convIds);
    return reservations
        .map(
          (r) => HostListingBookingThread(
            reservation: r,
            conversation: byResId[r.id],
            lastMessagePreview: byResId[r.id] != null
                ? previews[byResId[r.id]!.id]
                : null,
          ),
        )
        .toList();
  }

  @override
  Future<List<ChatMessageRow>> messages(String conversationId) =>
      _remote.listMessages(conversationId);

  @override
  Stream<List<ChatMessageRow>> watchMessages(String conversationId) =>
      _remote.watchMessages(conversationId);

  @override
  Future<ChatMessageRow> send({
    required String conversationId,
    required String senderId,
    required String text,
  }) => _remote.sendMessage(
    conversationId: conversationId,
    senderId: senderId,
    text: text,
  );

  @override
  Future<void> markRead(String messageId) => _remote.markMessageRead(messageId);
}
