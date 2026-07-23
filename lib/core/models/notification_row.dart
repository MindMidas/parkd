enum NotificationHub { reservations, hosting, account }

class NotificationHubCounts {
  const NotificationHubCounts({
    required this.total,
    required this.reservations,
    required this.hosting,
    required this.account,
    required this.hostingBookings,
    required this.hostingReviews,
  });

  const NotificationHubCounts.empty()
    : total = 0,
      reservations = 0,
      hosting = 0,
      account = 0,
      hostingBookings = 0,
      hostingReviews = 0;

  final int total;
  final int reservations;
  final int hosting;
  final int account;
  final int hostingBookings;
  final int hostingReviews;
}

enum ParkdNotificationType {
  reservationConfirmed('reservation_confirmed'),
  messageReceived('message_received'),
  reviewReceived('review_received');

  const ParkdNotificationType(this.databaseValue);

  final String databaseValue;

  static ParkdNotificationType? fromDatabase(String? value) {
    for (final type in values) {
      if (type.databaseValue == value) return type;
    }
    return null;
  }
}

/// Privacy-minimized event row from `public.notifications`.
class NotificationRow {
  const NotificationRow({
    required this.id,
    required this.userId,
    required this.type,
    required this.sourceEntityType,
    required this.sourceEntityId,
    required this.data,
    required this.isRead,
    required this.createdAt,
    this.actorUserId,
    this.readAt,
  });

  final String id;
  final String userId;
  final String? actorUserId;
  final ParkdNotificationType type;
  final String sourceEntityType;
  final String sourceEntityId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  NotificationHub get hub => switch (data['hub']) {
    'reservations' => NotificationHub.reservations,
    'hosting' => NotificationHub.hosting,
    _ => NotificationHub.account,
  };

  String? get reservationId {
    final value = data['reservation_id'];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return sourceEntityType == 'reservation' ? sourceEntityId : null;
  }

  String get title => switch (type) {
    ParkdNotificationType.reservationConfirmed => 'Booking confirmed',
    ParkdNotificationType.messageReceived => 'New message',
    ParkdNotificationType.reviewReceived => 'New review',
  };

  String get body => switch (type) {
    ParkdNotificationType.reservationConfirmed =>
      'A driver completed test checkout for your listing.',
    ParkdNotificationType.messageReceived =>
      'Open the conversation to read the message.',
    ParkdNotificationType.reviewReceived => 'You received a new rating.',
  };

  static NotificationRow fromJson(Map<String, dynamic> json) {
    final parsedType = ParkdNotificationType.fromDatabase(
      json['type'] as String?,
    );
    if (parsedType == null) {
      throw FormatException('Unsupported notification type: ${json['type']}');
    }
    final rawData = json['data_json'];
    return NotificationRow(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      actorUserId: json['actor_user_id'] as String?,
      type: parsedType,
      sourceEntityType: json['source_entity_type'] as String,
      sourceEntityId: json['source_entity_id'] as String,
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
      isRead: json['is_read'] as bool? ?? false,
      readAt: _parseDate(json['read_at']),
      createdAt: _parseDate(json['created_at']) ?? DateTime.now().toUtc(),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
