import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_row.dart';

class NotificationsRemote {
  NotificationsRemote(this._client);

  final SupabaseClient _client;

  Future<List<NotificationRow>> listForUser(String userId) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map(
          (e) => NotificationRow.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<int> unreadCount(String userId) async {
    final rows = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (rows as List).length;
  }

  Future<void> markRead(String notificationId) async {
    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', notificationId);
  }

  Future<void> markAllRead(String userId) async {
    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', userId).eq('is_read', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _client.from('notifications').delete().eq('id', notificationId);
  }

  // Unread reservation_confirmed rows whose data_json.listing_id matches.
  Future<void> markReservationConfirmedReadForListing({
    required String userId,
    required String listingId,
  }) async {
    final lid = listingId.trim();
    if (lid.isEmpty) return;
    final rows = await _client
        .from('notifications')
        .select('id, data_json')
        .eq('user_id', userId)
        .eq('type', 'reservation_confirmed')
        .eq('is_read', false);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final e in rows as List) {
      final m = Map<String, dynamic>.from(e as Map);
      final data = m['data_json'];
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      final rowLid = map['listing_id'];
      final rowLidStr = rowLid is String ? rowLid.trim() : null;
      if (rowLidStr != lid) continue;
      await _client.from('notifications').update({
        'is_read': true,
        'read_at': now,
      }).eq('id', m['id'] as String);
    }
  }

  // Mark trip chat notifications read when conversation or reservation id matches.
  Future<void> markMessageNotificationsReadForThread({
    required String userId,
    String? conversationId,
    required String reservationId,
  }) async {
    final rid = reservationId.trim();
    if (rid.isEmpty) return;
    final cid = conversationId?.trim();
    final rows = await _client
        .from('notifications')
        .select('id, data_json')
        .eq('user_id', userId)
        .eq('type', 'message_received')
        .eq('is_read', false);
    final now = DateTime.now().toUtc().toIso8601String();
    for (final e in rows as List) {
      final m = Map<String, dynamic>.from(e as Map);
      final data = m['data_json'];
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      final rowCid = map['conversation_id'];
      final rowCidStr = rowCid is String ? rowCid.trim() : null;
      final rowRid = map['reservation_id'];
      final rowRidStr = rowRid is String ? rowRid.trim() : null;

      final matchesConv = cid != null &&
          cid.isNotEmpty &&
          rowCidStr != null &&
          rowCidStr == cid;
      final matchesRes =
          rowRidStr != null && rowRidStr == rid;
      if (!matchesConv && !matchesRes) continue;

      final id = m['id'] as String;
      await _client.from('notifications').update({
        'is_read': true,
        'read_at': now,
      }).eq('id', id);
    }
  }

  Stream<List<NotificationRow>> watchForUser(String userId) {
    final controller = StreamController<List<NotificationRow>>();
    RealtimeChannel? channel;

    Future<void> emitLatest() async {
      try {
        final rows = await listForUser(userId);
        if (!controller.isClosed) controller.add(rows);
      } catch (e, st) {
        if (!controller.isClosed) controller.addError(e, st);
      }
    }

    controller.onListen = () {
      channel = _client
          .channel('notifications:user:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
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
}
