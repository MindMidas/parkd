import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message_row.dart';
import '../models/conversation_row.dart';

// conversations + messages, participants set by trigger on insert
class ConversationsRemote {
  ConversationsRemote(this._client);

  final SupabaseClient _client;

  Future<ConversationRow> ensureConversation(String reservationId) async {
    final existing = await _client
        .from('conversations')
        .select()
        .eq('reservation_id', reservationId)
        .maybeSingle();
    if (existing != null) {
      return ConversationRow.fromJson(Map<String, dynamic>.from(existing));
    }
    final row = await _client
        .from('conversations')
        .insert({'reservation_id': reservationId})
        .select()
        .single();
    return ConversationRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<ConversationRow>> listForUser(String userId) async {
    final rows = await _client
        .from('conversations')
        .select()
        .or('host_id.eq.$userId,driver_id.eq.$userId')
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((e) => ConversationRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ConversationRow>> listByReservationIds(
    List<String> reservationIds,
  ) async {
    if (reservationIds.isEmpty) return [];
    final rows = await _client
        .from('conversations')
        .select()
        .inFilter('reservation_id', reservationIds);
    return (rows as List)
        .map((e) => ConversationRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // latest message text per convo (one query)
  Future<Map<String, String>> lastMessagePreviewByConversationId(
    Iterable<String> conversationIds,
  ) async {
    final ids = conversationIds.toList();
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('messages')
        .select('conversation_id, message, created_at')
        .inFilter('conversation_id', ids)
        .order('created_at', ascending: false);
    final out = <String, String>{};
    for (final e in rows as List) {
      final m = Map<String, dynamic>.from(e as Map);
      final cid = m['conversation_id'] as String?;
      final text = m['message'] as String?;
      if (cid == null || text == null) continue;
      out.putIfAbsent(cid, () => text);
    }
    return out;
  }

  Future<List<ChatMessageRow>> listMessages(String conversationId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((e) => ChatMessageRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Stream<List<ChatMessageRow>> watchMessages(String conversationId) {
    final controller = StreamController<List<ChatMessageRow>>();
    RealtimeChannel? channel;

    Future<void> emitLatest() async {
      try {
        final rows = await listMessages(conversationId);
        if (!controller.isClosed) controller.add(rows);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller.onListen = () {
      channel = _client
          .channel('messages:conversation:$conversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (_) => emitLatest(),
          )
          .subscribe((status, error) {});
      emitLatest();
    };

    controller.onCancel = () async {
      final c = channel;
      if (c != null) {
        await _client.removeChannel(c);
      }
    };

    return controller.stream;
  }

  Future<ChatMessageRow> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    final row = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message': text,
        })
        .select()
        .single();
    return ChatMessageRow.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> markMessageRead(String messageId) async {
    await _client.from('messages').update({'status': 'read'}).eq('id', messageId);
  }
}
