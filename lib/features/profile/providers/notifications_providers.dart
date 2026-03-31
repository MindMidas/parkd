import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/notification_row.dart';
import '../../../core/supabase/notifications_remote.dart';
import '../../auth/providers/auth_providers.dart';

final notificationsRemoteProvider = Provider<NotificationsRemote>((ref) {
  return NotificationsRemote(ref.watch(supabaseClientProvider));
});

final myNotificationsProvider = StreamProvider<List<NotificationRow>>((ref) {
  final uid = ref.watch(currentSessionProvider)?.user.id;
  if (uid == null) {
    return Stream.value(const <NotificationRow>[]);
  }
  return ref.read(notificationsRemoteProvider).watchForUser(uid);
});

final myUnreadNotificationsCountProvider = Provider<int>((ref) {
  final rows = ref.watch(myNotificationsProvider).value ?? const <NotificationRow>[];
  return rows.where((n) => !n.isRead).length;
});
