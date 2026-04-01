import '../models/notification_row.dart';

String? _messageCtx(NotificationRow n) =>
    NotificationRow.normalizeMessageContext(n.dataJson['message_context']);

/// `data_json.reservation_id` when present.
String? notificationReservationId(NotificationRow n) {
  final raw = n.dataJson['reservation_id'];
  if (raw is! String || raw.trim().isEmpty) return null;
  return raw.trim();
}

/// Unread rows that belong to the Hosting tab (host-facing).
bool isUnreadHostingHubNotification(NotificationRow n) {
  if (n.isRead) return false;
  switch (n.type) {
    case 'reservation_confirmed':
    case 'review_received':
      return true;
    case 'message_received':
      return _messageCtx(n) == 'booking';
    default:
      return false;
  }
}

/// Unread rows that belong to the Reservations tab (driver-facing messages).
bool isUnreadReservationsHubNotification(NotificationRow n) {
  if (n.isRead) return false;
  return n.type == 'message_received' && _messageCtx(n) == 'reservation';
}

/// Hosting hub → Manage Listings (ratings on listings).
bool isUnreadHostingManageListingsNotification(NotificationRow n) {
  return !n.isRead && n.type == 'review_received';
}
