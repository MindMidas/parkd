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
