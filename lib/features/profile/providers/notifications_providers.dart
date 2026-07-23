import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/notification_row.dart';
import '../../../core/supabase/notifications_remote.dart';
import '../../auth/providers/auth_providers.dart';

final notificationsRemoteProvider = Provider<NotificationsRemote>((ref) {
  return NotificationsRemote(ref.watch(supabaseClientProvider));
});

final myNotificationFeedProvider = StreamProvider<NotificationFeedSnapshot>((
  ref,
) {
  final userId = ref.watch(currentSessionProvider)?.user.id;
  if (userId == null) {
    return Stream.value(const NotificationFeedSnapshot.empty());
  }
  return ref.watch(notificationsRemoteProvider).watchLatest(userId);
});

final myLatestNotificationsProvider = Provider<List<NotificationRow>>((ref) {
  return ref.watch(myNotificationFeedProvider).value?.latest ??
      const <NotificationRow>[];
});

final myNotificationHubCountsProvider = Provider<NotificationHubCounts>((ref) {
  return ref.watch(myNotificationFeedProvider).value?.unread ??
      const NotificationHubCounts.empty();
});

final hostingBookingNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(myNotificationHubCountsProvider).hostingBookings;
});

final hostingReviewNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(myNotificationHubCountsProvider).hostingReviews;
});

final reservationNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(myNotificationHubCountsProvider).reservations;
});
