/// Mirrors public.message_status in supabase/schema.sql
enum MessageDeliveryStatus {
  sent,
  read;

  static MessageDeliveryStatus fromWire(String? value) {
    if (value == null) return MessageDeliveryStatus.sent;
    for (final e in MessageDeliveryStatus.values) {
      if (e.name == value) return e;
    }
    return MessageDeliveryStatus.sent;
  }
}
