class NotificationRow {
  const NotificationRow({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.dataJson,
    required this.isRead,
    this.sourceEntityType,
    this.sourceEntityId,
    this.readAt,
    this.pushSentAt,
    this.pushError,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> dataJson;
  final String? sourceEntityType;
  final String? sourceEntityId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? pushSentAt;
  final String? pushError;
  final DateTime createdAt;

  // message_received only: short role tag from data_json.message_context (booking vs reservation).
  String? get messageReceivedSenderRoleBracket {
    if (type != 'message_received') return null;
    final kw = normalizeMessageContext(dataJson['message_context']);
    if (kw == 'booking') return '(DRIVER)';
    if (kw == 'reservation') return '(HOST)';
    return null;
  }

  // Same as above, but if message_context is missing guess from host vs driver ids and sender_id.
  String? resolvedMessageSenderRoleBracket({
    String? reservationHostId,
    String? reservationDriverId,
  }) {
    final fromCtx = messageReceivedSenderRoleBracket;
    if (fromCtx != null) return fromCtx;
    if (type != 'message_received') return null;
    final raw = dataJson['sender_id'];
    final sid = raw is String ? raw.trim() : null;
    if (sid == null || sid.isEmpty) return null;
    final h = reservationHostId?.trim();
    final d = reservationDriverId?.trim();
    if (h != null && h.isNotEmpty && sid == h) return '(HOST)';
    if (d != null && d.isNotEmpty && sid == d) return '(DRIVER)';
    return null;
  }

  // Normalized message_context string for message_received, or null.
  static String? normalizeMessageContext(Object? raw) {
    if (raw is! String) return null;
    final s = raw.trim().toLowerCase();
    return s.isEmpty ? null : s;
  }

  static NotificationRow fromJson(Map<String, dynamic> json) {
    return NotificationRow(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      dataJson: json['data_json'] is Map
          ? Map<String, dynamic>.from(json['data_json'] as Map)
          : const <String, dynamic>{},
      sourceEntityType: json['source_entity_type'] as String?,
      sourceEntityId: json['source_entity_id'] as String?,
      isRead: (json['is_read'] as bool?) ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      pushSentAt: json['push_sent_at'] != null
          ? DateTime.parse(json['push_sent_at'] as String)
          : null,
      pushError: json['push_error'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
