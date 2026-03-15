/// Mirrors public.availability_specific (date-range slots).
/// Schema: database/schema.sql
class AvailabilitySpecific {
  const AvailabilitySpecific({
    required this.id,
    required this.listingId,
    required this.startDatetime,
    required this.endDatetime,
    this.createdAt,
  });

  final String id;
  final String listingId;
  final DateTime startDatetime;
  final DateTime endDatetime;
  final DateTime? createdAt;

  /// For UI: "Sep 15, 2026 • 9:00 AM".
  static String formatDateTime(DateTime dt) {
    const months = 'JanFebMarAprMayJunJulAugSepOctNovDec';
    final m = months.substring((dt.month - 1) * 3, dt.month * 3);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    final min = dt.minute.toString().padLeft(2, '0');
    return '${m} ${dt.day}, ${dt.year} • $hour:$min $ampm';
  }

  String get fromDisplay => formatDateTime(startDatetime);
  String get toDisplay => formatDateTime(endDatetime);

  static AvailabilitySpecific fromJson(Map<String, dynamic> json) {
    return AvailabilitySpecific(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      startDatetime: DateTime.parse(json['start_datetime'] as String),
      endDatetime: DateTime.parse(json['end_datetime'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listing_id': listingId,
        'start_datetime': startDatetime.toIso8601String(),
        'end_datetime': endDatetime.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}
