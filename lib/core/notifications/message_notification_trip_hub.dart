import '../models/notification_row.dart';
import '../models/reservation_row.dart';
import 'notification_hub_counts.dart';

/// Which main-tab hub a `message_received` row belongs to for the recipient.
enum MessageTripHub {
  /// Recipient is host (message about a booking on their listing).
  hostingTab,
  /// Recipient is driver (message about their trip).
  reservationsTab,
}

typedef GetReservation = Future<ReservationRow?> Function(String id);

/// Uses `message_context` when set; otherwise infers from reservation + `sender_id`
/// (same idea as [NotificationRow.resolvedMessageSenderRoleBracket]).
Future<MessageTripHub?> resolveMessageTripHub(
  NotificationRow n,
  GetReservation getReservation,
) async {
  if (n.type != 'message_received') return null;
  final ctx = NotificationRow.normalizeMessageContext(n.dataJson['message_context']);
  if (ctx == 'booking') return MessageTripHub.hostingTab;
  if (ctx == 'reservation') return MessageTripHub.reservationsTab;

  final rid = notificationReservationId(n);
  final raw = n.dataJson['sender_id'];
  final sid = raw is String ? raw.trim() : null;
  if (rid == null || sid == null || sid.isEmpty) return null;
  final r = await getReservation(rid);
  if (r == null) return null;
  if (sid == r.hostId) return MessageTripHub.reservationsTab;
  if (sid == r.driverId) return MessageTripHub.hostingTab;
  return null;
}
