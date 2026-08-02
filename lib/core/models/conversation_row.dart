// Mirrors public.conversations
class ConversationRow {
  const ConversationRow({
    required this.id,
    required this.reservationId,
    required this.hostId,
    required this.driverId,
    required this.isClosed,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String reservationId;
  final String hostId;
  final String driverId;
  final bool isClosed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static ConversationRow fromJson(Map<String, dynamic> json) {
    return ConversationRow(
      id: json['id'] as String,
      reservationId: json['reservation_id'] as String,
      hostId: json['host_id'] as String,
      driverId: json['driver_id'] as String,
      isClosed: json['is_closed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
