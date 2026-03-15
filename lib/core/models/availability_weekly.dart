/// Mirrors public.availability_weekly. day_of_week: 0 = Sunday … 6 = Saturday.
/// Schema: database/schema.sql
class AvailabilityWeekly {
  const AvailabilityWeekly({
    required this.id,
    required this.listingId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.createdAt,
  });

  final String id;
  final String listingId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final DateTime? createdAt;

  static const List<String> _dayNames = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];

  String get dayLabel => _dayNames[dayOfWeek.clamp(0, 6)];

  /// For UI: "9:15 AM to 1:00 PM" (assumes startTime/endTime are ISO time or "HH:mm").
  String get timeRangeDisplay => '$startTime to $endTime';

  static AvailabilityWeekly fromJson(Map<String, dynamic> json) {
    return AvailabilityWeekly(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      startTime: _formatTime(json['start_time']),
      endTime: _formatTime(json['end_time']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  static String _formatTime(dynamic v) {
    if (v == null) return '--:--';
    final s = v.toString();
    if (s.length >= 5 && s.contains(':')) return s.substring(0, 5);
    return s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
        'created_at': createdAt?.toIso8601String(),
      };
}
