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
