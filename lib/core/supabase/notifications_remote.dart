import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_row.dart';

class NotificationFeedSnapshot {
  const NotificationFeedSnapshot({required this.latest, required this.unread});

  const NotificationFeedSnapshot.empty()
    : latest = const <NotificationRow>[],
      unread = const NotificationHubCounts.empty();

  final List<NotificationRow> latest;
  final NotificationHubCounts unread;
}

class NotificationsRemote {
  NotificationsRemote(this._client);

  static const int pageSize = 30;

  final SupabaseClient _client;

  Future<List<NotificationRow>> listPage({
    required String userId,
    DateTime? before,
    int limit = pageSize,
  }) async {
    var query = _client.from('notifications').select().eq('user_id', userId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(limit.clamp(1, 100));
    return (rows as List)
        .map(
          (row) =>
              NotificationRow.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  Future<NotificationFeedSnapshot> fetchLatest(String userId) async {
    final latest = await listPage(userId: userId);
    final total = await _client
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', userId)
        .eq('is_read', false);
    final reservations = await _client
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', userId)
        .eq('is_read', false)
        .contains('data_json', const {'hub': 'reservations'});
    final hosting = await _client
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', userId)
        .eq('is_read', false)
        .contains('data_json', const {'hub': 'hosting'});
    final hostingReviews = await _client
        .from('notifications')
        .count(CountOption.exact)
        .eq('user_id', userId)
        .eq('is_read', false)
        .eq('type', ParkdNotificationType.reviewReceived.databaseValue)
        .contains('data_json', const {'hub': 'hosting'});
    return NotificationFeedSnapshot(
      latest: latest,
      unread: NotificationHubCounts(
        total: total,
        reservations: reservations,
        hosting: hosting,
        account: (total - reservations - hosting).clamp(0, total),
        hostingBookings: (hosting - hostingReviews).clamp(0, hosting),
        hostingReviews: hostingReviews,
      ),
    );
  }

  Stream<NotificationFeedSnapshot> watchLatest(String userId) {
    final controller = StreamController<NotificationFeedSnapshot>();
    RealtimeChannel? channel;
    Timer? refreshDebounce;
    Timer? fallbackRefresh;
    var fetching = false;
    var fetchAgain = false;

    Future<void> emitLatest() async {
      if (fetching) {
        fetchAgain = true;
        return;
      }
      fetching = true;
      try {
        final snapshot = await fetchLatest(userId);
        if (!controller.isClosed) controller.add(snapshot);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      } finally {
        fetching = false;
        if (fetchAgain && !controller.isClosed) {
          fetchAgain = false;
          unawaited(emitLatest());
        }
      }
    }

    void scheduleRefresh() {
      refreshDebounce?.cancel();
      refreshDebounce = Timer(
        const Duration(milliseconds: 120),
        () => unawaited(emitLatest()),
      );
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
            callback: (_) => scheduleRefresh(),
          )
          .subscribe((status, error) {
            if (status == RealtimeSubscribeStatus.channelError ||
                status == RealtimeSubscribeStatus.timedOut) {
              scheduleRefresh();
            }
          });
      fallbackRefresh = Timer.periodic(
        const Duration(minutes: 1),
        (_) => scheduleRefresh(),
      );
      unawaited(emitLatest());
    };

    controller.onCancel = () async {
      refreshDebounce?.cancel();
      fallbackRefresh?.cancel();
      final activeChannel = channel;
      if (activeChannel != null) {
        await _client.removeChannel(activeChannel);
      }
      if (!controller.isClosed) await controller.close();
    };

    return controller.stream;
  }

  Future<bool> markRead(String notificationId) async {
    final result = await _client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
    return result == true;
  }

  Future<int> markAllRead() async {
    final result = await _client.rpc('mark_all_notifications_read');
    return (result as num?)?.toInt() ?? 0;
  }

  Future<bool> deleteNotification(String notificationId) async {
    final result = await _client.rpc(
      'delete_notification',
      params: {'p_notification_id': notificationId},
    );
    return result == true;
  }

  Future<int> markMessageNotificationsRead(String reservationId) async {
    final result = await _client.rpc(
      'mark_message_notifications_read',
      params: {'p_reservation_id': reservationId},
    );
    return (result as num?)?.toInt() ?? 0;
  }
}
